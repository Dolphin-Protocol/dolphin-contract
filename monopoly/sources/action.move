module monopoly::action;


public enum Action has copy, store, drop {
    Buy,
    Pay,
    Jail,
    Chance
}

public(package) fun buyAction(): Action {
    Action::Buy
}

public(package) fun payAction(): Action {
    Action::Pay
}

public(package) fun jailAction(): Action {
    Action::Jail
}

public(package) fun changeAction(): Action {
    Action::Chance
}
