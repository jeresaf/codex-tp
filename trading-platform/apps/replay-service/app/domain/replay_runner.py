def run_replay_stub(payload: dict) -> dict:
    return {
        'status': 'queued',
        'message': 'Replay skeleton created',
        'dataset_version_id': payload['dataset_version_id'],
        'start_time': payload['start_time'],
        'end_time': payload['end_time'],
    }
