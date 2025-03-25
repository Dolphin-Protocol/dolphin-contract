module autonomous_world::profile;

// === Imports ===

// sui std
use std::{
    string::{Self, String,},  
};

// sui framework
use sui::{
    package,
    display,
    clock::{Clock},
};

// autonomous world
use autonomous_world::{
    registry::{ WelcomeTicket,},
};

// OTW
public struct PROFILE has drop{}

// === Structs ===
public struct Profile has key, store{
    id: UID,
    first_name: String,
    last_name: String,
    img_blob_id: String, // blob id
    pfp_blob_id: String, // blob id
    birthday: u64,
}

// === Hot Potato ===


// === Constants ===

// === Errors ===

// === Events ===


// === Init Function ===
fun init (otw: PROFILE, ctx: &mut TxContext){
    // setup Kapy display
        let keys = vector[
            string::utf8(b"name"),
            string::utf8(b"description"),
            string::utf8(b"image_url"),
            string::utf8(b"project_url"),
        ];

        let values = vector[
            // name
            string::utf8(b"Suitizen: {first_name} {last_name}"),
            // description
            string::utf8(b"A Citizen of the Sui World"),
            // image_url
            string::utf8(b""),
            // project_url
            string::utf8(b""),
        ];

        let deployer = ctx.sender();
        let publisher = package::claim(otw, ctx);
        let mut displayer = display::new_with_fields<Profile>(
            &publisher, keys, values, ctx,
        );

        display::update_version(&mut displayer);

        transfer::public_transfer(displayer, deployer);
        transfer::public_transfer(publisher, deployer);
} 

// === Public Write Functions ===
public fun mint(
    ticket: WelcomeTicket,
    img_blob_id: String,
    pfp_blob_id: String,
    clock: &Clock,
    ctx: &mut TxContext,
): Profile {

    let first_name = ticket.first_name();
    let last_name = ticket.last_name();

    ticket.burn_ticket();

    Profile{
        id: object::new(ctx),
        first_name,
        last_name,
        img_blob_id,
        pfp_blob_id,
        birthday: clock.timestamp_ms(),
    }
    
}



// === Public Read Functions ===


// === Private Functions


// === Assert Function ===


