def next_tasks(definition: dict, current_state: str) -> list[dict]:
    return definition.get('transitions', {}).get(current_state, [])
