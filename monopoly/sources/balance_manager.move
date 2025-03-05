module monopoly::balance_manager;

use sui::vec_map::{Self, VecMap};
use sui::balance::{Self, Balance, Supply};

const ENotExistPlayer: u64 = 101;

public struct BalanceManager<phantom T> has key, store{
    id: UID,
    supply: Supply<T>,
    balances: VecMap<address, Balance<T>>
}


public fun new<T>(supply: Supply<T>, ctx: &mut TxContext): BalanceManager<T> {
    BalanceManager{
        id: object::new(ctx),
        supply,
        balances: vec_map::empty()
    }
}

public fun burn<T>(
    self: &mut BalanceManager<T>,
    balance: Balance<T>
):u64 {
    self.supply.decrease_supply(balance)
}

/// @return; player's new balance value
public fun add_balance<T>(
    self: &mut BalanceManager<T>,
    mut player: address,
    value: u64
):u64 {
    if(!self.balances.contains(&player)){
        self.balances.insert(player, balance::zero());
    };

    self.balances[&mut player].join(self.supply.increase_supply(value))
}

/// @return; deducted value
public fun sub_balance<T>(
    self: &mut BalanceManager<T>,
    mut player: address,
    value: u64
):u64 {
    if(!self.balances.contains(&player)){
        self.balances.insert(player, balance::zero());
    };

    self.supply.decrease_supply(self.balances[&mut player].split(value))
}

/// @return; deducted value
public fun saturating_sub_balance<T>(
    self: &mut BalanceManager<T>,
    mut player: address,
    value: u64
): u64{
    if(!self.balances.contains(&player)){
        self.balances.insert(player, balance::zero());
    };
    
    let balance = &mut self.balances[&mut player];
    let removed_balance = if(balance.value() > value){
        balance.split(value)
    }else{
        balance.withdraw_all()
    };

    self.supply.decrease_supply(removed_balance)
}

//@return; transferred amount
public fun transfer<T>(
    self: &mut BalanceManager<T>,
    mut from: address,
    mut to: address,
    value: u64
): u64 {
    let split_balance = self.balances[&mut from].split(value);
    self.balances[&mut to].join(split_balance)
}

// === Public View Functions ===
public fun balance_of<T>(
    self: &BalanceManager<T>,
    player: address
):&Balance<T> {
    // to bypass lifetime constraint, we'll refuse to use index method
    let mut idx_opt = self.balances.get_idx_opt(&player);

    assert!(idx_opt.is_some(), ENotExistPlayer);

    let (_, balance) = self.balances.get_entry_by_idx(idx_opt.extract());

    balance
}

public fun balance_of_mut<T>(
    self: &mut BalanceManager<T>,
    player: address
):&mut Balance<T> {
    &mut self.balances[&player]
}

public fun supply<T>(
    self: &BalanceManager<T>
):u64 {
    self.supply.supply_value()
}
