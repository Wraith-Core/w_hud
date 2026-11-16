"""Exercise the HUD's normal load paths with in-memory storage and interleaved reads."""
import re
import sqlite3
import unittest
from pathlib import Path

from lupa.lua54 import LuaRuntime


RESOURCE = Path(__file__).resolve().parents[1]


class NeedsLoadTests(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(":memory:")
        self.addCleanup(self.db.close)
        self.db.execute("CREATE TABLE w_hud_needs (cid TEXT PRIMARY KEY, hunger INT, thirst INT)")
        self.after_read = None
        self.before_write = None
        self.lua = LuaRuntime()
        self.g = self.lua.globals()
        self.g.read_row = self.read_row
        self.g.write_row = self.write_row
        self.lua.execute("""
            local noop = function() end
            source, character = 1, "first"
            api, events = {}, {}
            exports = setmetatable({
                w_lib = {FwGetCharacterIdentifier=function() return character end}
            }, {__call=function(_,name,fn) api[name]=fn end})
            function RegisterNetEvent(name, fn) events[name]=fn end
            AddEventHandler, CreateThread, TriggerClientEvent, Player = noop, noop, noop, noop
            w = {callback={register=noop}}
            WFwSrv = {seed=function() return {hunger=82, thirst=65} end}
            local function write(sql, params) return write_row(sql, params) end
            local writer = setmetatable({await=write}, {__call=function(_,...) return write(...) end})
            MySQL = {single={await=function(...) return read_row(...) end}, insert=writer, update=writer}
        """)
        path = RESOURCE / "server" / "metabolism.lua"
        self.lua.execute(path.read_text(encoding="utf-8-sig"), name="metabolism.lua")

    def read_row(self, sql, params):
        # Take the snapshot before a competing callback is allowed to resume.
        row = self.db.execute(sql, [params[i] for i in range(1, len(params) + 1)]).fetchone()
        if self.after_read is not None:
            action, self.after_read = self.after_read, None
            action()
        if row is not None:
            return self.lua.table(hunger=row[0], thirst=row[1])

    def write_row(self, sql, params):
        if self.before_write is not None:
            action, self.before_write = self.before_write, None
            action()
        # SQLite enforces the same unique character key. Translate only the upsert dialect.
        sql = re.sub(r"ON\s+DUPLICATE\s+KEY\s+UPDATE", "ON CONFLICT(cid) DO UPDATE SET", sql, flags=re.I)
        sql = re.sub(r"VALUES\s*\(\s*(\w+)\s*\)", r"excluded.\1", sql, flags=re.I)
        lookup = "SELECT hunger, thirst FROM w_hud_needs WHERE cid=?"
        previous = self.db.execute(lookup, (params[1],)).fetchone()
        self.db.execute(sql, [params[i] for i in range(1, len(params) + 1)])
        current = self.db.execute(lookup, (params[1],)).fetchone()
        return int(previous != current)  # MariaDB reports zero for a no-op update.

    def load(self):
        self.g.events["w_hud:server:load"]()

    def live_needs(self):
        row = self.g.api.GetNeeds(1)
        return None if row is None else (row.hunger, row.thirst)

    def insert(self, cid, hunger, thirst):
        self.db.execute("INSERT INTO w_hud_needs VALUES (?, ?, ?)", (cid, hunger, thirst))

    def test_late_first_read_keeps_the_other_loads_live_update(self):
        def competing_request():
            # The admin read lazily loads the same character before the login SELECT returns.
            pair = self.g.api.GetNeedsPair(1)
            self.assertEqual((pair.hunger, pair.thirst), (82, 65))
            self.g.api.SetNeed(1, "hunger", 36)

        self.after_read = competing_request
        self.load()
        self.assertEqual(self.db.execute("SELECT COUNT(*) FROM w_hud_needs").fetchone()[0], 1)
        self.assertEqual(self.live_needs(), (36, 65))

    def test_concurrent_live_change_during_first_load_reread_is_preserved(self):
        def during_reread():
            self.g.api.SetNeed(1, "thirst", 7)

        def after_initial_read():
            self.after_read = during_reread

        self.before_write = after_initial_read
        self.load()
        self.assertEqual(self.live_needs(), (82, 7))

    def test_insert_by_another_writer_wins_over_framework_seed(self):
        self.before_write = lambda: self.insert("first", 0, 17)
        self.load()
        self.assertEqual(self.live_needs(), (0, 17))
        self.assertEqual(self.db.execute("SELECT hunger, thirst FROM w_hud_needs").fetchone(), (0, 17))

    def test_absent_framework_seed_starts_at_defaults(self):
        self.lua.execute("WFwSrv.seed = function() return nil end")
        self.load()
        self.assertEqual(self.live_needs(), (100, 100))

    def test_row_removed_before_reread_is_not_published(self):
        self.db.execute("CREATE TRIGGER remove_row AFTER INSERT ON w_hud_needs "
                        "BEGIN DELETE FROM w_hud_needs WHERE cid = NEW.cid; END")
        self.load()
        self.assertIsNone(self.live_needs())

    def test_existing_character_uses_saved_needs_and_preserves_live_changes(self):
        self.insert("first", 24, 0)
        self.load()
        self.assertEqual(self.live_needs(), (24, 0))
        self.g.api.SetNeed(1, "thirst", 13)
        self.load()
        self.assertEqual(self.live_needs(), (24, 13))

    def test_previous_character_cannot_publish_a_late_read(self):
        self.insert("first", 9, 8)
        self.insert("second", 29, 28)
        def switch_character():
            self.g.character = "second"
            self.load()
        self.after_read = switch_character
        self.load()
        self.assertEqual(self.live_needs(), (29, 28))


if __name__ == "__main__":
    unittest.main()
