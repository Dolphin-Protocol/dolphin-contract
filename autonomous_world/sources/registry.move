module autonomous_world::registry;

// === Imports ===

// sui std
use std::{
    string::{ Self, String},
};

// sui framework
use sui::{
    vec_set::{Self, VecSet},
    event,
    clock::{Clock},
    table::{Self, Table},
};


// sui ns
use suins::{ 
    suins_registration::{SuinsRegistration},
};

// autonomous world
use autonomous_world::{
    config::{ AdminCap,},
};

// === Structs ===
public struct Registry has key {
    id: UID,
    reg_tab: Table<String, ID>,
    supported_version: VecSet<u64>,
}

// === Hot Potato ===
public struct WelcomeTicket {
    first_name: String, 
    last_name: String
}

// === Constants ===
const VERSION: u64 = 1;

// === Errors ===
const EVersionNotSupported: u64 = 1000;
const ENsExpired: u64 = 1001;
const ENameAlreadyExisted: u64 = 1002;

// === Events ===
public struct RegistryAddVersion has copy, drop{
    version: u64,
}

// ===Init Function ===
fun init (ctx: &mut TxContext){
    let registry = Registry{
        id: object::new(ctx),
        reg_tab: table::new<String, ID>(ctx),
        supported_version: vec_set::singleton(VERSION),
    };

    transfer::transfer(registry, ctx.sender());
}

// === Public Write Functions ===

// verify
public fun verify(
    self: &Registry,
    sui_ns: &SuinsRegistration,
    clock: &Clock,
): WelcomeTicket{

    assert_if_ns_expired_by_ns(sui_ns, clock);
    
    let first_name = *sui_ns.domain().sld();
    let last_name =  *sui_ns.domain().tld();

    let mut name = string::utf8(b"");
    name.append(first_name);
    name.append(last_name);

    self.assert_if_name_already_existed(name);

    WelcomeTicket{
        first_name,
        last_name,
    }
}


// add version
entry fun add_version(
    self: &mut Registry,
    _: &AdminCap,
    version: u64
){
    self.assert_if_version_not_matched();
    self.supported_version.insert(version);

    event::emit(RegistryAddVersion{
        version,
    });
}

// === Public Read Functions ===
public fun first_name(
    ticket: &WelcomeTicket,
): String{
    ticket.first_name
}

public fun last_name(
    ticket: &WelcomeTicket,
): String{
    ticket.last_name
}

// === Public Package Functions ===
public(package) fun burn_ticket(
    ticket: WelcomeTicket,
){
    let WelcomeTicket{
        first_name: _,
        last_name: _,
    } = ticket;
}

// === Assert Functions ===

fun assert_if_version_not_matched(
    self: &Registry,
) {
    let version = VERSION;
    assert!(self.supported_version.contains(&version), EVersionNotSupported);
}

fun assert_if_ns_expired_by_ns(
    sui_ns: &SuinsRegistration,
    clock: &Clock,
){
    assert!(!sui_ns.has_expired(clock), ENsExpired);
}

fun assert_if_name_already_existed(
    self: &Registry,
    name: String,
){
    assert!(self.reg_tab.contains(name), ENameAlreadyExisted);
}