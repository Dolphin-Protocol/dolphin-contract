module monopoly::event {
    use sui::event;

    public struct ActionRequestEvent<T: drop + copy> has copy, drop {
        game: ID,
        player: address,
        new_pos_idx: u64,
        parameter: T,
    }

    /// Dynamic ACtion Request Type
    public fun emit_action_request<T: drop + copy>(
        game: ID,
        player: address,
        new_pos_idx: u64,
        parameter: T,
    ) {
        event::emit(ActionRequestEvent {
            game,
            player,
            new_pos_idx,
            parameter,
        });
    }
}
