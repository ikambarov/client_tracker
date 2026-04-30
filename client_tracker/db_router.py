from django.conf import settings


class PrimaryReplicaRouter:
    def db_for_read(self, model, **hints):
        reader = getattr(settings, 'READER_DATABASE_ALIAS', '')
        if reader:
            return reader
        return None

    def db_for_write(self, model, **hints):
        return 'default'

    def allow_relation(self, obj1, obj2, **hints):
        database_aliases = {'default'}
        reader = getattr(settings, 'READER_DATABASE_ALIAS', '')
        if reader:
            database_aliases.add(reader)

        if obj1._state.db in database_aliases and obj2._state.db in database_aliases:
            return True
        return None

    def allow_migrate(self, db, app_label, model_name=None, **hints):
        return db == 'default'
