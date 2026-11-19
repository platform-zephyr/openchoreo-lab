// Rendu hors cluster des triggers et gabarits d'argocd-notifications-cm (T-489).
// Évalue chaque condition `when` et `oncePer` avec expr-lang/expr et chaque gabarit avec text/template + sprig, aux
// versions de github.com/argoproj/notifications-engine épinglé par Argo CD v3.5.1 (go.mod de ce dossier), sur des
// Application factices. Exige : la table de déclenchement attendue, un YAML de notification valide, aucune fuite des
// champs à texte libre (IP factice dans health.message et operationState.message), aucun `<no value>`.
// Usage : go run . <chemin de argocd-notifications-cm.yaml>   (rc 1 au premier écart)
package main

import (
	"bytes"
	"fmt"
	"os"
	"sort"
	"strings"
	"text/template"

	"github.com/Masterminds/sprig/v3"
	"github.com/expr-lang/expr"
	"sigs.k8s.io/yaml"
)

const leak = "192.0.2.10" // TEST-NET-1 (RFC 5737), factice

type tcase struct {
	app  string
	want string // trigger attendu, "" = aucun
}

var cases = map[string]tcase{
	"healthy": {`{"metadata":{"name":"lab-o-whoami"},"spec":{"project":"lab-o","source":{"repoURL":"https://github.com/platform-zephyr/openchoreo-lab","path":"generated/namespaces/default/projects/whoami"}},"status":{"sync":{"status":"Synced","revision":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"},"health":{"status":"Healthy","message":"` + leak + `"}}}`, "on-lab-success"},
	"degraded-k": {`{"metadata":{"name":"lab-k-foo"},"spec":{"project":"lab-k","source":{"repoURL":"https://github.com/example/sandbox.git","path":"apps/foo"}},"status":{"sync":{"status":"OutOfSync","revision":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"},"health":{"status":"Degraded","message":"` + leak + `"},"operationState":{"phase":"Failed","message":"dial ` + leak + `"}}}`, "on-lab-failure"},
	"sync-failed": {`{"metadata":{"name":"lab-o-bar"},"spec":{"project":"lab-o","source":{"repoURL":"https://github.com/example/r","path":"p"}},"status":{"sync":{"status":"OutOfSync","revision":"cccccccccccccccccccccccccccccccccccccccc"},"health":{"status":"Missing"},"operationState":{"phase":"Error"}}}`, "on-lab-failure"},
	"progressing": {`{"metadata":{"name":"lab-o-baz"},"spec":{"project":"lab-o","source":{"repoURL":"https://github.com/example/r","path":"p"}},"status":{"sync":{"status":"Synced","revision":"dddddddddddddddddddddddddddddddddddddddd"},"health":{"status":"Progressing"}}}`, "on-lab-neutral"},
	"no-operation": {`{"metadata":{"name":"lab-o-new"},"spec":{"project":"lab-o","source":{"repoURL":"https://github.com/example/r","path":"p"}},"status":{"sync":{"status":"OutOfSync","revision":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"},"health":{"status":"Missing"}}}`, ""},
	"root-not-lab-o": {`{"metadata":{"name":"lab-root"},"spec":{"project":"lab-root","source":{"repoURL":"https://github.com/example/r","path":"p"}},"status":{"sync":{"status":"Synced","revision":"ffffffffffffffffffffffffffffffffffffffff"},"health":{"status":"Degraded"}}}`, ""},
	"platform": {`{"metadata":{"name":"lab-platform"},"spec":{"project":"lab-platform","source":{"repoURL":"https://github.com/example/r","path":"platform"}},"status":{"sync":{"status":"Synced","revision":"ffffffffffffffffffffffffffffffffffffffff"},"health":{"status":"Healthy"}}}`, ""},
	"multi-source": {`{"metadata":{"name":"lab-k-ms"},"spec":{"project":"lab-k","sources":[{"repoURL":"https://github.com/example/r"}]},"status":{"sync":{"status":"Synced","revision":"1111111111111111111111111111111111111111"},"health":{"status":"Healthy"}}}`, ""},
}

var conclusion = map[string]string{"on-lab-success": "success", "on-lab-failure": "failure", "on-lab-neutral": "neutral"}

func fail(format string, a ...any) {
	fmt.Printf("FAIL "+format+"\n", a...)
	os.Exit(1)
}

func main() {
	raw, err := os.ReadFile(os.Args[1])
	if err != nil {
		fail("%v", err)
	}
	var cm struct {
		Data map[string]string `json:"data"`
	}
	if err := yaml.Unmarshal(raw, &cm); err != nil {
		fail("ConfigMap illisible : %v", err)
	}
	names := make([]string, 0, len(cases))
	for n := range cases {
		names = append(names, n)
	}
	sort.Strings(names)
	for _, name := range names {
		tc := cases[name]
		var app map[string]any
		if err := yaml.Unmarshal([]byte(tc.app), &app); err != nil {
			fail("%s : app factice illisible : %v", name, err)
		}
		fired := []string{}
		for _, trig := range []string{"on-lab-success", "on-lab-failure", "on-lab-neutral"} {
			var conds []struct {
				When    string   `json:"when"`
				OncePer string   `json:"oncePer"`
				Send    []string `json:"send"`
			}
			if err := yaml.Unmarshal([]byte(cm.Data["trigger."+trig]), &conds); err != nil || len(conds) == 0 {
				fail("trigger %s illisible ou vide : %v", trig, err)
			}
			for _, c := range conds {
				env := map[string]any{"app": app}
				out, err := expr.Eval(c.When, env)
				if err != nil {
					fail("%s / %s : when : %v", name, trig, err)
				}
				once, err := expr.Eval(c.OncePer, env)
				if err != nil || once == nil || once == "" {
					fail("%s / %s : oncePer vide ou en erreur : %v", name, trig, err)
				}
				if out != true {
					continue
				}
				fired = append(fired, trig)
				for _, t := range c.Send {
					render(name, trig, t, cm.Data["template."+t], app)
				}
			}
		}
		got := strings.Join(fired, ",")
		if got != tc.want {
			fail("%s : triggers déclenchés %q, attendu %q", name, got, tc.want)
		}
		fmt.Printf("PASS %-15s -> %q\n", name, got)
	}
}

func render(name, trig, tname, body string, app map[string]any) {
	// Comme notifications-engine : le gabarit est d'abord lu comme YAML, puis chaque champ est un text/template.
	var pre map[string]any
	if err := yaml.Unmarshal([]byte(body), &pre); err != nil {
		fail("gabarit %s : YAML invalide AVANT rendu : %v", tname, err)
	}
	tpl, err := template.New(tname).Funcs(sprig.TxtFuncMap()).Parse(body)
	if err != nil {
		fail("gabarit %s : %v", tname, err)
	}
	var b bytes.Buffer
	if err := tpl.Execute(&b, map[string]any{"app": app, "context": map[string]string{}}); err != nil {
		fail("%s / %s : rendu : %v", name, tname, err)
	}
	s := b.String()
	if strings.Contains(s, leak) || strings.Contains(s, "<no value>") {
		fail("%s / %s : fuite d'un champ libre ou valeur absente :\n%s", name, tname, s)
	}
	var n struct {
		GitHub struct {
			RepoURLPath  string `json:"repoURLPath"`
			RevisionPath string `json:"revisionPath"`
			CheckRun     struct {
				Name       string `json:"name"`
				DetailsURL string `json:"details_url"`
				Status     string `json:"status"`
				Conclusion string `json:"conclusion"`
				Output     struct {
					Title   string `json:"title"`
					Summary string `json:"summary"`
				} `json:"output"`
			} `json:"checkRun"`
		} `json:"github"`
	}
	if err := yaml.Unmarshal(b.Bytes(), &n); err != nil {
		fail("%s / %s : YAML rendu invalide : %v\n%s", name, tname, err, s)
	}
	cr := n.GitHub.CheckRun
	meta := app["metadata"].(map[string]any)
	switch {
	case cr.Name != "argocd/"+meta["name"].(string):
		fail("%s / %s : nom de check run %q", name, tname, cr.Name)
	case cr.Status != "completed" || cr.Conclusion != conclusion[trig]:
		fail("%s / %s : status %q conclusion %q", name, tname, cr.Status, cr.Conclusion)
	case len(n.GitHub.RevisionPath) != 40:
		fail("%s / %s : révision %q", name, tname, n.GitHub.RevisionPath)
	case !strings.HasPrefix(cr.DetailsURL, "https://github.com/") || strings.Contains(cr.DetailsURL, ".git/"):
		fail("%s / %s : details_url %q", name, tname, cr.DetailsURL)
	case cr.Output.Title == "" || cr.Output.Summary == "":
		fail("%s / %s : titre ou résumé vide", name, tname)
	}
}
