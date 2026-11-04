#!/usr/bin/env python3
"""Build and validate UIRPG content.

Authored YAML -> content/data.json. The runtime never reads YAML.

Usage:
    python tools/build_content.py            # build + validate
    python tools/build_content.py --check    # validate only
"""

from __future__ import annotations

import argparse
import json
import math
import sys
import textwrap
from pathlib import Path

try:
    import yaml
except ImportError:  # pragma: no cover - tooling guard
    sys.exit("PyYAML is required. Run: tools/.venv/bin/pip install pyyaml")

ROOT = Path(__file__).resolve().parent.parent
CONTENT = ROOT / "content"
OUT = CONTENT / "data.json"

ALLOWED_TYPES = {"monster", "spell", "trap"}
ALLOWED_ATTRIBUTES = {"ember", "tide", "verdant", "umbra", "neutral"}
ALLOWED_LINEAGES = {"beast", "spirit", "construct", "wanderer", None}
ALLOWED_RARITIES = {"common", "uncommon", "rare", "legendary"}
ALLOWED_ROLES = {
    "threat", "answer", "draw", "enabler", "payoff", "glue", "resource",
}
ALLOWED_KEYWORDS = {
    "kindle", "echo", "flip", "pierce", "fleet", "veil", "bind", "rite",
    "banish", "offer", "set", "chain",
}
ALLOWED_TRIGGERS = {
    "on_call", "on_set", "on_flip", "on_attack", "on_damage", "on_destroy",
    "on_banish", "dawn", "dusk", "on_draw", "on_discard", "continuous",
    "on_activate",
}
ALLOWED_ACTIONS = {
    "damage", "heal", "draw", "discard", "destroy", "banish", "summon_token",
    "buff", "debuff", "return_from_remains", "negate_attack", "lane_buff",
    "on_destroy_summon", "dusk_discard", "banish_self_instead",
}
ALLOWED_MOD_KINDS = {"prefix", "suffix", "verdigris"}
ALLOWED_MOD_STATS = {"atk", "defense", "offer"}
TIER_GATE = {1: 1, 2: 10, 3: 25, 4: 45, 5: 70}

errors: list[str] = []
warnings: list[str] = []


def fail(msg: str) -> None:
    errors.append(msg)


def warn(msg: str) -> None:
    warnings.append(msg)


def load_yaml(path: Path):
    try:
        with path.open("r", encoding="utf-8") as fh:
            return yaml.safe_load(fh)
    except Exception as exc:  # noqa: BLE001
        fail(f"{path.relative_to(ROOT)}: YAML parse failed: {exc}")
        return None


def type_line(card: dict) -> str:
    bits = [card["type"].upper(), card["attribute"].upper()]
    if card.get("lineage"):
        bits.append(card["lineage"].upper())
    return " · ".join(bits)


def card_power(card: dict) -> int:
    atk = card.get("atk") or 0
    defense = card.get("defense") or 0
    offer = card.get("offer") or 0
    effect_value = card.get("effect_value") or 0
    return math.floor(atk / 100 + defense / 150 + offer * 1.5 + effect_value)


def validate_effect(where: str, effect) -> None:
    if effect is None:
        return
    if not isinstance(effect, dict):
        fail(f"{where}: effect must be a mapping or null")
        return
    trigger = effect.get("trigger")
    if trigger not in ALLOWED_TRIGGERS:
        fail(f"{where}: unknown trigger {trigger!r}")
    steps = effect.get("steps", [])
    if not isinstance(steps, list) or not steps:
        fail(f"{where}: effect.steps must be a non-empty list")
        return
    for i, step in enumerate(steps):
        if not isinstance(step, dict):
            fail(f"{where}: step {i} must be a mapping")
            continue
        action = step.get("action")
        if action not in ALLOWED_ACTIONS:
            fail(f"{where}: step {i} unknown action {action!r}")
        if action in {"damage", "heal", "draw", "discard", "dusk_discard"}:
            if "amount" not in step and not step.get("amount_from_value"):
                fail(f"{where}: step {i} ({action}) needs amount")
        if action == "damage" and "target" not in step:
            fail(f"{where}: step {i} (damage) needs target")
        if action in {"summon_token", "on_destroy_summon"}:
            if "atk" not in step or "defense" not in step:
                fail(f"{where}: step {i} ({action}) needs atk/defense")
        limit = effect.get("limit")
        if limit not in (None, "once_per_turn", "once_per_duel"):
            fail(f"{where}: bad limit {limit!r}")


def load_cards() -> list[dict]:
    cards = []
    for path in sorted((CONTENT / "cards").glob("*.yaml")):
        data = load_yaml(path)
        if data is None:
            continue
        data["_path"] = str(path.relative_to(ROOT))
        cards.append(data)
    ids = set()
    for card in cards:
        where = card.get("_path", "card")
        cid = card.get("id")
        if not cid:
            fail(f"{where}: missing id")
            continue
        if cid in ids:
            fail(f"{where}: duplicate id {cid}")
        ids.add(cid)
        for field in ("set", "name", "type", "attribute", "rarity", "role", "text"):
            if field not in card:
                fail(f"{where}: missing {field}")
        if card.get("type") not in ALLOWED_TYPES:
            fail(f"{where}: bad type {card.get('type')!r}")
        if card.get("attribute") not in ALLOWED_ATTRIBUTES:
            fail(f"{where}: bad attribute {card.get('attribute')!r}")
        if card.get("lineage") not in ALLOWED_LINEAGES:
            fail(f"{where}: bad lineage {card.get('lineage')!r}")
        if card.get("rarity") not in ALLOWED_RARITIES:
            fail(f"{where}: bad rarity {card.get('rarity')!r}")
        if card.get("role") not in ALLOWED_ROLES:
            fail(f"{where}: bad role {card.get('role')!r}")
        offer = card.get("offer", 0)
        if not isinstance(offer, int) or offer < 0 or offer > 2:
            fail(f"{where}: offer must be 0..2")
        name = card.get("name", "")
        if len(name) > 24:
            fail(f"{where}: name is {len(name)} chars (max 24)")
        if len(type_line(card)) > 40:
            fail(f"{where}: type line is {len(type_line(card))} chars (max 40)")
        text = card.get("text", "")
        if len(text) > 180:
            fail(f"{where}: rules text is {len(text)} chars (max 180)")
        lines = textwrap.wrap(text, width=32) if text else []
        if len(lines) > 5:
            fail(f"{where}: rules wrap to {len(lines)} lines at M (max 5)")
        keywords = card.get("keywords") or []
        unknown = set(keywords) - ALLOWED_KEYWORDS
        if unknown:
            fail(f"{where}: unknown keywords {sorted(unknown)}")
        if card.get("type") == "monster":
            if not isinstance(card.get("atk"), int) or not isinstance(card.get("defense"), int):
                fail(f"{where}: monsters need integer atk/defense")
            elif not (0 <= card["atk"] <= 3000 and 0 <= card["defense"] <= 3000):
                fail(f"{where}: atk/defense must be 0..3000")
            if card.get("spell_kind") or card.get("trap_kind"):
                fail(f"{where}: monster cannot have spell_kind/trap_kind")
        else:
            if card.get("atk") is not None or card.get("defense") is not None:
                fail(f"{where}: non-monster must not print atk/defense")
            if card["type"] == "spell" and card.get("spell_kind") not in {"normal", "continuous", "equip"}:
                fail(f"{where}: spell needs spell_kind normal|continuous|equip")
            if card["type"] == "trap" and card.get("trap_kind") not in {"normal", "continuous", "counter"}:
                fail(f"{where}: trap needs trap_kind normal|continuous|counter")
        effect_value = card.get("effect_value", 0)
        if not isinstance(effect_value, int) or not 0 <= effect_value <= 10:
            fail(f"{where}: effect_value must be 0..10")
        validate_effect(where, card.get("effect"))
        card["power"] = card_power(card)
        card["type_line"] = type_line(card)
        card.pop("_path", None)
    return cards


def load_list(name: str) -> list[dict]:
    path = CONTENT / name
    data = load_yaml(path)
    if data is None:
        return []
    if not isinstance(data, list):
        fail(f"{path.relative_to(ROOT)}: expected a list")
        return []
    return data


def validate_mods(mods: list[dict]) -> None:
    ids = set()
    for mod in mods:
        where = f"mod {mod.get('id')}"
        if not mod.get("id") or mod["id"] in ids:
            fail(f"{where}: missing/duplicate id")
        ids.add(mod.get("id"))
        if mod.get("kind") not in ALLOWED_MOD_KINDS:
            fail(f"{where}: bad kind")
        if mod.get("stat") and mod["stat"] not in ALLOWED_MOD_STATS:
            fail(f"{where}: bad stat")
        lo = mod.get("tier_min", 1)
        hi = mod.get("tier_max", 5)
        if not (1 <= lo <= hi <= 5):
            fail(f"{where}: bad tier range")
        values = mod.get("values") or {}
        power = mod.get("power") or {}
        for tier in range(lo, hi + 1):
            if str(tier) not in {str(k) for k in values}:
                fail(f"{where}: missing value for tier {tier}")
            if str(tier) not in {str(k) for k in power}:
                fail(f"{where}: missing power for tier {tier}")
        if "trigger" in mod:
            validate_effect(where, {"trigger": mod["trigger"], "steps": mod.get("steps", [])})


def validate_reagents(reagents: list[dict]) -> None:
    if len(reagents) != 10:
        warn(f"launch scope is 10 reagents; found {len(reagents)}")
    ids = set()
    for reagent in reagents:
        where = f"reagent {reagent.get('id')}"
        if not reagent.get("id") or reagent["id"] in ids:
            fail(f"{where}: missing/duplicate id")
        ids.add(reagent.get("id"))
        if reagent.get("rarity") not in ALLOWED_RARITIES:
            fail(f"{where}: bad rarity")
        for field in ("name", "verb", "tab", "rule"):
            if not reagent.get(field):
                fail(f"{where}: missing {field}")


def validate_folios(folios: list[dict]) -> None:
    ids = set()
    for folio in folios:
        where = f"folio {folio.get('id')}"
        if not folio.get("id") or folio["id"] in ids:
            fail(f"{where}: missing/duplicate id")
        ids.add(folio.get("id"))
        if not (1 <= folio.get("cards", 0) <= 5):
            fail(f"{where}: cards must be 1..5")
        if not (1 <= folio.get("provenance", 0) <= 100):
            fail(f"{where}: provenance must be 1..100")


def validate_deck(where: str, deck: list[dict], side: list[dict], cards_by_id: dict[str, dict]) -> None:
    counts: dict[str, int] = {}
    total = 0
    for entry in deck or []:
        cid = entry.get("def")
        count = entry.get("count", 0)
        if cid not in cards_by_id:
            fail(f"{where}: unknown card {cid!r}")
            continue
        if not isinstance(count, int) or count <= 0:
            fail(f"{where}: bad count for {cid}")
            continue
        counts[cid] = counts.get(cid, 0) + count
        total += count
    if total != 40:
        fail(f"{where}: main deck has {total} cards (need 40)")
    side_total = 0
    for entry in side or []:
        cid = entry.get("def")
        count = entry.get("count", 0)
        if cid not in cards_by_id:
            fail(f"{where}: unknown sideboard card {cid!r}")
            continue
        counts[cid] = counts.get(cid, 0) + count
        side_total += count
    if side and side_total > 5:
        fail(f"{where}: sideboard has {side_total} cards (max 5)")
    for cid, count in counts.items():
        card = cards_by_id[cid]
        limit = 1 if card["rarity"] == "legendary" else 3
        if count > limit:
            fail(f"{where}: {cid} x{count} exceeds limit {limit}")


def build(write: bool = True) -> None:
    cards = load_cards()
    cards_by_id = {c["id"]: c for c in cards if c.get("id")}
    mods = load_list("mods.yaml")
    reagents = load_list("reagents.yaml")
    folios = load_list("folios.yaml")
    starters = load_list("starters.yaml")
    inks = load_list("inks.yaml")
    shimmers = load_list("shimmer.yaml")
    themes = load_list("themes.yaml")
    sets = load_list("sets.yaml")

    validate_mods(mods)
    validate_reagents(reagents)
    validate_folios(folios)

    for starter in starters:
        validate_deck(f"starter {starter.get('id')}", starter.get("deck"), starter.get("sideboard"), cards_by_id)
    opponents = []
    for path in sorted((CONTENT / "opponents").glob("*.yaml")):
        opponent = load_yaml(path)
        if opponent is None:
            continue
        opponent["_path"] = str(path.relative_to(ROOT))
        validate_deck(f"opponent {opponent.get('id')}", opponent.get("deck"), None, cards_by_id)
        opponent.pop("_path", None)
        opponents.append(opponent)

    if sets:
        set_ids = {s.get("id") for s in sets}
        for card in cards:
            if card.get("set") not in set_ids:
                fail(f"card {card.get('id')}: unknown set {card.get('set')!r}")

    data = {
        "content_version": 1,
        "rules_version": 1,
        "cards": cards,
        "sets": sets,
        "opponents": opponents,
        "mods": mods,
        "reagents": reagents,
        "folios": folios,
        "starters": starters,
        "inks": inks,
        "shimmers": shimmers,
        "themes": themes,
    }

    if errors:
        print("CONTENT BUILD FAILED", file=sys.stderr)
        for err in errors:
            print(f"  error: {err}", file=sys.stderr)
        for warning in warnings:
            print(f"  warning: {warning}", file=sys.stderr)
        sys.exit(1)

    if warnings:
        for warning in warnings:
            print(f"warning: {warning}", file=sys.stderr)

    if write:
        OUT.write_text(json.dumps(data, indent=2, ensure_ascii=False, default=str) + "\n", encoding="utf-8")
        print(f"content: {len(cards)} cards, {len(opponents)} opponents, {len(mods)} mods, "
              f"{len(reagents)} reagents, {len(folios)} folios, {len(starters)} starters -> {OUT.relative_to(ROOT)}")
    else:
        print(f"content validation passed: {len(cards)} cards, {len(opponents)} opponents, "
              f"{len(mods)} mods, {len(reagents)} reagents, {len(folios)} folios, {len(starters)} starters")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="validate without writing")
    args = parser.parse_args()
    build(write=not args.check)


if __name__ == "__main__":
    main()
