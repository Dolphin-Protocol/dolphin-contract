module autonomous_world::config;

// === Imports ===

// sui framework
use sui::{
    vec_set::{Self, VecSet},
    event,
};

// === Structs ===
public struct Config has key {
    id: UID,
    supported_version: VecSet<u64>,
}

public struct AdminCap has key {
    id: UID,
}


// === Constants ===
const VERSION: u64 = 1;

// === Errors ===
const EVersionNotSupported:u64 = 0;


// === Events ===
public struct ConfigAddVersion has copy, drop{
    version: u64,
}

// === Init Function ===
fun init(
    ctx: &mut TxContext
){
    let config = Config{
        id: object::new(ctx),
        supported_version: vec_set::singleton(VERSION),
    };
    transfer::transfer(config, ctx.sender());
}

// === Public Write Functions ===

// add version
entry fun add_version(
    self: &mut Config,
    _: &AdminCap,
    version: u64
){
    self.assert_if_version_not_matched();
    self.supported_version.insert(version);

    event::emit(ConfigAddVersion{
        version,
    });
}



// === Public Read Functions ===


// === Assert Function ===
fun assert_if_version_not_matched(
    self: &Config,
) {
    let version = VERSION;
    assert!(self.supported_version.contains(&version), EVersionNotSupported);
}