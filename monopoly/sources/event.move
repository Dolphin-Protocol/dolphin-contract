module monopoly::event {
    use std::type_name::TypeName;
    use sui::{event, vec_map::VecMap};

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
