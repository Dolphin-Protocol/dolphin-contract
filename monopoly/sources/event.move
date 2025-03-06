module monopoly::event;
use std::type_name::TypeName;

use sui::vec_map::VecMap;
use sui::event;

use monopoly::action::Action;

public struct ActionRequestEvent<T: drop + copy> has drop, copy {
    game: ID,
    player: address,
    new_pos_idx: u64,
    action: Action,
    parameter: T
}


/// Dynamic ACtion Request Type
public fun emit_action_request<T: drop + copy>(
    game: ID,
    player: address,
    new_pos_idx: u64,
    action: Action,
    parameter: T
){
    event::emit(
        ActionRequestEvent {
            game,
            player,
            new_pos_idx,
            action,
            parameter,
        }
    );
}
