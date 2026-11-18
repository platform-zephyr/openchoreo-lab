"""Stockage bronze : source=<x>/dt=AAAA-MM-JJ/part-0.parquet, upsert par cle naturelle (idempotent, T-201).

Rejeu : lire la partition, remplacer les lignes de meme cle, reecrire entierement (jamais de mise a jour en place),
tri par cle, aucun horodatage d'ecriture : deux rejeux du meme jeu donnent le meme contenu. Parquet via pyarrow
(import paresseux) ; `MemoryStore` sert aux tests sans dependance.
"""
from __future__ import annotations

import os
import tempfile
from pathlib import Path

from model import SOURCES, contains_secret, partition_day


def merge_rows(existing: list[dict], new: list[dict], key: str) -> list[dict]:
    by_key = {r[key]: r for r in existing}
    by_key.update({r[key]: r for r in new})
    return [by_key[k] for k in sorted(by_key)]


class MemoryStore:
    def __init__(self) -> None:
        self.parts: dict[tuple[str, str], list[dict]] = {}

    def read(self, source: str, day: str) -> list[dict]:
        return list(self.parts.get((source, day), []))

    def write(self, source: str, day: str, rows: list[dict]) -> None:
        self.parts[(source, day)] = list(rows)

    def days(self, source: str) -> list[str]:
        return sorted(d for s, d in self.parts if s == source)


class ParquetStore:
    def __init__(self, root: Path) -> None:
        import pyarrow  # noqa: F401  (echec explicite si absent)
        self.root = Path(root)

    def _path(self, source: str, day: str) -> Path:
        return self.root / f"source={source}" / f"dt={day}" / "part-0.parquet"

    def read(self, source: str, day: str) -> list[dict]:
        import pyarrow.parquet as pq
        p = self._path(source, day)
        return pq.read_table(p).to_pylist() if p.exists() else []

    def write(self, source: str, day: str, rows: list[dict]) -> None:
        import pyarrow as pa
        import pyarrow.parquet as pq
        p = self._path(source, day)
        p.parent.mkdir(parents=True, exist_ok=True)
        fields = SOURCES[source][1]
        table = pa.Table.from_pylist([{f: r.get(f) for f in fields} for r in rows])
        fd, tmp = tempfile.mkstemp(dir=p.parent, suffix=".tmp")
        os.close(fd)
        try:
            pq.write_table(table, tmp, compression="zstd")
            os.replace(tmp, p)
        finally:
            if os.path.exists(tmp):
                os.unlink(tmp)

    def days(self, source: str) -> list[str]:
        base = self.root / f"source={source}"
        return sorted(d.name[3:] for d in base.glob("dt=*")) if base.exists() else []


def upsert(store, source: str, rows: list[dict]) -> dict[str, int]:
    """Ecrit `rows` par partition de jour. Rend le nombre de lignes par jour touche. Refuse un secret apparent."""
    key, fields = SOURCES[source]
    grouped: dict[str, list[dict]] = {}
    for row in rows:
        if contains_secret(row):
            raise ValueError(f"valeur ressemblant a un secret refusee ({source} {row.get(key)})")
        clean = {f: row.get(f) for f in fields}  # liste blanche, meme si l'appelant ajoute un champ
        grouped.setdefault(partition_day(row), []).append(clean)
    out = {}
    for day, new in sorted(grouped.items()):
        merged = merge_rows(store.read(source, day), new, key)
        store.write(source, day, merged)
        out[day] = len(merged)
    return out
