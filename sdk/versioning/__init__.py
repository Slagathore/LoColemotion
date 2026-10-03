"""Public SporeSpore SDK compatibility and schema-migration helpers."""

from importlib import import_module
from typing import Any

__all__ = [
    "SchemaMigrationError",
    "load_schema_registry",
    "migrate_record",
]


def __getattr__(name: str) -> Any:
    """Lazily expose helpers without preloading the executable CLI module."""

    if name not in __all__:
        raise AttributeError(name)
    migrations = import_module(".migrations", __name__)
    return getattr(migrations, name)
