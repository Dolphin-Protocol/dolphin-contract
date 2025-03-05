module monopoly::action;


public enum Action has copy, store, drop {
    Buy,
    Jail,
    Chance,
    DoNothing
}

public(package) fun buyAction(): Action {
    Action::Buy
}

public(package) fun jailAction(): Action {
    Action::Jail
}

public(package) fun chanceAction(): Action {
    Action::Chance
}

public(package) fun doNothingAction(): Action {
    Action::DoNothing
}
