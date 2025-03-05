#[test_only]
#[allow(unused)]
module monopoly::monopoly_tests;
use std::string::{Self, String};

use sui::vec_map::{Self, VecMap};
use sui::clock::{Self, Clock};
use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};

use monopoly::monopoly::{Self, AdminCap, Game};
use monopoly::cell::{ Self, HouseCell };
use monopoly::action;

use monopoly::test_utils;

const START_TIME: u64 = 1000_000;

// ref: https://www.falstad.com/monopoly.html
const PRICE_INFOS: vector<vector<u64>> = vector[
    vector[10, 30, 90],
    vector[20, 60, 180],
    vector[30, 90, 270],
    vector[30, 90, 270],
    vector[40, 100, 300],
    vector[50, 150, 450],
    vector[50, 150, 450],
    vector[60, 180, 500],
    vector[70, 200, 550],
    vector[70, 200, 550],
    // 11th
    vector[80, 220, 600],
    vector[90, 250, 700],
    vector[90, 250, 700],
    vector[100, 300, 750],
    vector[110, 330, 800],
    vector[110, 330, 800],
    vector[120, 360, 850],
    vector[130, 390, 900],
    vector[130, 390, 900],
    vector[150, 450 ,1000],
];

fun prices_by_level(): vector<VecMap<u8, u64>>{
    let price_infos = PRICE_INFOS;
    price_infos.map!(|price_info|{
        let mut prices_by_levels = vec_map::empty<u8, u64>();

        0_u64.range_do!<()>(price_info.length(), |idx|{
            prices_by_levels.insert((idx as u8), price_info[idx]);
        });

        prices_by_levels
    })
}

fun people():(address, address, address, address, address){
    (@0xA, @0xB, @0xC, @0xD, @0xE)
}

fun setup(): (Scenario, Clock){
    let (admin, b, c, d, e) = people();

    let mut scenario = test::begin(@0xA);
    let s = &mut scenario;
    let mut clock = clock::create_for_testing(ctx(s));

    let price_infos = prices_by_level();

    clock::set_for_testing(&mut clock, START_TIME); 
    tx_context::increment_epoch_timestamp(ctx(s), START_TIME);

    monopoly::init_for_testing(ctx(s));

    s.next_tx(admin);{
        let admin_cap = test::take_from_sender<AdminCap>(s);

        let players = vector[b, c, d, e];

        let mut game = admin_cap.new(players, ctx(s));
        // we will have 20 cells in 6x6 board game
        // setup game cells
        0_u64.range_do!<()>(price_infos.length(), |idx|{
            let price_info = price_infos[idx];
            let (levels, prices) = price_info.into_keys_values();
            let cell = cell::new_house_cell(string::utf8(b"name"), levels, prices, ctx(s));

            let action = if(idx == 15){
                action::jailAction()
            }else if(idx % 5 == 0){
                action::doNothingAction()
            }else if(idx % 3 == 0){
                action::chanceAction()
            }else{
                action::buyAction()
            };

            game.add_cell(&admin_cap, idx, cell, action);
        });

        game.settle_game_creation(&admin_cap, admin);

        test::return_to_sender(s, admin_cap);
    };

    s.next_tx(admin);{
        let game = test::take_from_sender<Game>(s);


        0_u64.range_do!<()>(game.num_of_cells(), |pos_index|{

            let house_cell = game.borrow_cell<HouseCell>(pos_index);

            let (name, level, prices) = house_cell.house_info();
            let price_info = price_infos[pos_index];

            assert!(name == string::utf8(b"name"));
            assert!(level == 0);

            test_utils::compare_vec_map(&prices, &price_info);
        });

        test::return_to_sender(s, game);
    };

    (scenario, clock)
}

#[test]
fun test_monopoly_basic(){
    let (mut scenario, mut clock) = setup();

    scenario.end();
    clock.destroy_for_testing();
}
