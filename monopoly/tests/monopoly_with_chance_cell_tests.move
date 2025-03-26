#[test_only]
#[allow(unused)]
module monopoly::monopoly_with_chance_cell_tests {
    use monopoly::{
        cell::{Self, Cell, DoNothingArgument},
        chance_cell::{
            Self,
            ChanceArgument,
            ChanceCell,
            ChanceRegistry,
            BalanceChance,
            TollChance,
            HouseChance,
            JailChance
        },
        balance,
        house_cell::{Self, HouseCell, BuyArgument},
        monopoly::{Self, AdminCap, Game, TurnCap, ActionRequest, Monopoly},
        test_utils
    };
    use std::{debug, string::{Self, String}, type_name};
    use sui::{
        clock::{Self, Clock},
        random::{Self, Random},
        test_scenario::{Self as test, Scenario, next_tx, ctx},
        vec_map::{Self, VecMap}
    };

    fun people(): (address, address, address, address, address) {
        (@0xA, @0xB, @0xC, @0xD, @0xE)
    }

    const START_TIME: u64 = 1000_000;

    // ref: https://www.falstad.com/monopoly.html
    const BUY_PRICE_INFOS: vector<vector<u64>> = vector[
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
    ];

    const SELL_PRICE_INFOS: vector<vector<u64>> = vector[
        vector[5, 15, 45],
        vector[10, 30, 90],
        vector[15, 45, 135],
        vector[15, 45, 135],
        vector[20, 50, 150],
        vector[25, 75, 225],
        vector[25, 75, 225],
        vector[30, 90, 250],
        vector[35, 100, 275],
        vector[35, 100, 275],
        // 11th
        vector[40, 110, 300],
        vector[45, 125, 350],
        vector[45, 125, 350],
        vector[50, 150, 375],
        vector[55, 165, 400],
        vector[55, 165, 400],
    ];

    const TOLL_INFOS: vector<vector<u64>> = vector[
        vector[15, 45, 135],
        vector[30, 90, 270],
        vector[45, 135, 405],
        vector[45, 135, 405],
        vector[60, 150, 450],
        vector[75, 225, 675],
        vector[75, 225, 675],
        vector[90, 270, 750],
        vector[105, 300, 825],
        vector[105, 300, 825],
        // 11th
        vector[120, 330, 900],
        vector[135, 375, 1050],
        vector[135, 375, 1050],
        vector[150, 450, 1125],
        vector[165, 495, 1200],
        vector[165, 495, 1200],
    ];

    fun names(): vector<String> {
        vector[
            string::utf8(b"START"),
            string::utf8(b"0"),
            string::utf8(b"1"),
            string::utf8(b"2"),
            string::utf8(b"3"),
            string::utf8(b"JAIL"),
            string::utf8(b"4"),
            string::utf8(b"5"),
            string::utf8(b"6"),
            string::utf8(b"7"),
            string::utf8(b"CHANCE-1"),
            string::utf8(b"8"),
            string::utf8(b"9"),
            string::utf8(b"10"),
            string::utf8(b"11"),
            string::utf8(b"CHANCE-2"),
            string::utf8(b"12"),
            string::utf8(b"13"),
            string::utf8(b"14"),
            string::utf8(b"15"),
        ]
    }

    fun descriptions(): vector<String> {
        vector[
            // Balance Chance (increase): 0-3
            string::utf8(b"You receive a surprise birthday gift!"),
            string::utf8(b"You found a hidden treasure!"),
            string::utf8(b"Your hard work paid off!"),
            string::utf8(b"You've won a small lottery!"),
            // Balance Chance (decrease) 4-8
            string::utf8(b"You've been fined for speeding!"),
            string::utf8(b"Unexpected repairs!"),
            string::utf8(b"You donated to charity!"),
            string::utf8(b"Your investment didn't pan out!"),
            // Toll Chance 9-40
            string::utf8(b"The 0 house toll doubled!"),
            string::utf8(b"The 0 house toll halved!"),
            string::utf8(b"The 1 house toll doubled!"),
            string::utf8(b"The 1 house toll halved!"),
            string::utf8(b"The 2 house toll doubled!"),
            string::utf8(b"The 2 house toll halved!"),
            string::utf8(b"The 3 house toll doubled!"),
            string::utf8(b"The 3 house toll halved!"),
            string::utf8(b"The 4 house toll doubled!"),
            string::utf8(b"The 4 house toll halved!"),
            string::utf8(b"The 5 house toll doubled!"),
            string::utf8(b"The 5 house toll halved!"),
            string::utf8(b"The 6 house toll doubled!"),
            string::utf8(b"The 6 house toll halved!"),
            string::utf8(b"The 7 house toll doubled!"),
            string::utf8(b"The 7 house toll halved!"),
            string::utf8(b"The 8 house toll doubled!"),
            string::utf8(b"The 8 house toll halved!"),
            string::utf8(b"The 9 house toll doubled!"),
            string::utf8(b"The 9 house toll halved!"),
            string::utf8(b"The 10 house toll doubled!"),
            string::utf8(b"The 10 house toll halved!"),
            string::utf8(b"The 11 house toll doubled!"),
            string::utf8(b"The 11 house toll halved!"),
            string::utf8(b"The 12 house toll doubled!"),
            string::utf8(b"The 12 house toll halved!"),
            string::utf8(b"The 13 house toll doubled!"),
            string::utf8(b"The 13 house toll halved!"),
            string::utf8(b"The 14 house toll doubled!"),
            string::utf8(b"The 14 house toll halved!"),
            string::utf8(b"The 15 house toll doubled!"),
            string::utf8(b"The 15 house toll halved!"),
            // Jail Chance 41-42
            string::utf8(b"You've been caught speeding! Go to jail for 1 round."),
            string::utf8(b"You broke the rules! Go directly to jail. Go to jail for 1 round."),
            // House Chance  43-74
            string::utf8(b"The 0 level up!"),
            string::utf8(b"The 0 level down!"),
            string::utf8(b"The 1 level up!"),
            string::utf8(b"The 1 level down!"),
            string::utf8(b"The 2 level up!"),
            string::utf8(b"The 2 level down!"),
            string::utf8(b"The 3 level up!"),
            string::utf8(b"The 3 level down!"),
            string::utf8(b"The 4 level up!"),
            string::utf8(b"The 4 level down!"),
            string::utf8(b"The 5 level up!"),
            string::utf8(b"The 5 level down!"),
            string::utf8(b"The 6 level up!"),
            string::utf8(b"The 6 level down!"),
            string::utf8(b"The 7 level up!"),
            string::utf8(b"The 7 level down!"),
            string::utf8(b"The 8 level up!"),
            string::utf8(b"The 8 level down!"),
            string::utf8(b"The 9 level up!"),
            string::utf8(b"The 9 level down!"),
            string::utf8(b"The 10 level up!"),
            string::utf8(b"The 10 level down!"),
            string::utf8(b"The 11 level up!"),
            string::utf8(b"The 11 level down!"),
            string::utf8(b"The 12 level up!"),
            string::utf8(b"The 12 level down!"),
            string::utf8(b"The 13 level up!"),
            string::utf8(b"The 13 level down!"),
            string::utf8(b"The 14 level up!"),
            string::utf8(b"The 14 level down!"),
            string::utf8(b"The 15 level up!"),
            string::utf8(b"The 15 level down!"),
        ]
    }

    fun prices_by_level(): (
        vector<VecMap<u8, u64>>,
        vector<VecMap<u8, u64>>,
        vector<VecMap<u8, u64>>,
    ) {
        let buy_price_infos = BUY_PRICE_INFOS;
        let sell_price_infos = SELL_PRICE_INFOS;
        let toll_infos = TOLL_INFOS;

        (buy_price_infos.map!(|buy_price_info| {
                let mut prices_by_levels = vec_map::empty<u8, u64>();

                buy_price_info.length().do!<()>(|idx| {
                    prices_by_levels.insert((idx + 1 as u8), buy_price_info[idx]);
                });

                prices_by_levels
            }), sell_price_infos.map!(|sell_price_info| {
                let mut prices_by_levels = vec_map::empty<u8, u64>();

                sell_price_info.length().do!<()>(|idx| {
                    prices_by_levels.insert((idx + 1as u8), sell_price_info[idx]);
                });

                prices_by_levels
            }), toll_infos.map!(|toll_info| {
                let mut prices_by_levels = vec_map::empty<u8, u64>();

                toll_info.length().do!<()>(|idx| {
                    prices_by_levels.insert((idx + 1 as u8), toll_info[idx]);
                });

                prices_by_levels
            }))
    }

    fun setup(): (Scenario, Clock) {
        let (admin, b, c, d, e) = people();

        let mut scenario = test::begin(@0xA);
        let s = &mut scenario;
        let mut clock = clock::create_for_testing(ctx(s));

        let initial_fund = 2000;

        clock::set_for_testing(&mut clock, START_TIME);
        tx_context::increment_epoch_timestamp(ctx(s), START_TIME);
        monopoly::init_for_testing(ctx(s));
        house_cell::init_for_testing(ctx(s));
        chance_cell::init_for_testing(ctx(s));

        s.next_tx(@0x0);
        {
            random::create_for_testing(ctx(s));
        };

        s.next_tx(admin);
        {
            let admin_cap = s.take_from_sender<AdminCap>();

            // order insertion determine plays order
            let players = vector[b, c, d, e];
            let max_rounds = 4;
            let max_steps = 12;
            let salary = 100;

            let mut game = admin_cap.new(players, max_rounds, max_steps, 100, ctx(s));
            house_cell::initialize_states(&mut game, &admin_cap);

            // 1) cell setup
            // we will have 20 cells in 6x6 board game
            // setup game cells
            {
                // set up house registry
                let names = names();
                let (buy_prices, sell_prices, tolls) = prices_by_level();
                let mut house_registry = s.take_shared<house_cell::HouseRegistry>();

                let mut house_idx = 0;
                names.length().do!<u64>(|idx: u64| {
                    if (idx != 0 && idx != 5 && idx != 10 && idx != 15) {
                        let buy_price = buy_prices[house_idx];
                        let sell_price = sell_prices[house_idx];
                        let toll = tolls[house_idx];

                        let (levels, buy_price_vec) = buy_price.into_keys_values();
                        let (_, sell_price_vec) = sell_price.into_keys_values();
                        let (_, toll_vec) = toll.into_keys_values();

                        house_registry.add_house_to_registry(
                            &admin_cap,
                            names[idx],
                            levels,
                            buy_price_vec,
                            sell_price_vec,
                            toll_vec,
                        );

                        house_idx = house_idx + 1;
                    };
                });

                //set up chance registry
                let mut chance_registry = s.take_shared<chance_cell::ChanceRegistry>();
                let descriptions = descriptions();
                house_idx = 0;
                descriptions.length().do!<u64>(|idx: u64| {
                    if (idx < 4) {
                        // balance chance (increase)
                        chance_cell::add_balance_chance_to_registry(
                            &mut chance_registry,
                            &admin_cap,
                            descriptions[idx],
                            true,
                            1000 * (idx + 1),
                        )
                    } else if (idx < 9) {
                        // balance chance (decrease)
                        chance_cell::add_balance_chance_to_registry(
                            &mut chance_registry,
                            &admin_cap,
                            descriptions[idx],
                            false,
                            500 * (idx - 3),
                        )
                    } else if (idx < 41) {
                        // toll chance
                        let bps = if (idx % 2 == 1) 20000 else 5000;
                        chance_cell::add_toll_chance_to_registry(
                            &mut chance_registry,
                            &admin_cap,
                            &house_registry,
                            descriptions[idx],
                            string::utf8((house_idx).to_string().into_bytes()),
                            bps,
                        );
                        if (idx % 2 == 0) house_idx = house_idx + 1;
                    } else if (idx < 43) {
                        // jail chance
                        chance_cell::add_jail_chance_to_registry(
                            &mut chance_registry,
                            &admin_cap,
                            descriptions[idx],
                            1,
                        );
                        house_idx = 0;
                    } else if (idx < 75) {
                        // house chance
                        let is_level_up = if (idx % 2 == 1) true else false;
                        chance_cell::add_house_chance_to_registry(
                            &mut chance_registry,
                            &admin_cap,
                            &house_registry,
                            descriptions[idx],
                            is_level_up,
                            string::utf8((house_idx).to_string().into_bytes()),
                        );
                        if (idx % 2 == 0) house_idx = house_idx + 1;
                    } else {
                        abort 1;
                    }
                });

                let mut house_idx = 0;
                20u64.do!<u64>(|idx: u64| {
                    let name = names[idx];
                    // cells order
                    if (idx == 0 || idx == 5) {
                        // cells at the corner are empty
                        let cell = cell::new_cell(name, ctx(s));
                        game.add_cell(&admin_cap, idx, cell);
                    } else if (idx == 10 || idx == 15) {
                        let cell = chance_cell::new_chance_cell(
                            &chance_registry,
                            &admin_cap,
                            name,
                            s.ctx(),
                        );
                        game.add_cell(&admin_cap, idx, cell);
                    } else {
                        let cell = house_cell::new_house_cell(
                            &house_registry,
                            name,
                            ctx(s),
                        );
                        house_cell::add_name_to_position(&mut game, name, idx as u8);
                        game.add_cell(&admin_cap, idx, cell);
                        house_idx = house_idx + 1;
                    };
                });

                test::return_shared(house_registry);
                test::return_shared(chance_registry);
            };

            // 2) Balance setup
            {
                let supply = monopoly::new_supply(&admin_cap);
                game.setup_balance<Monopoly>(&admin_cap, supply, initial_fund, ctx(s));
            };

            game.settle_game_creation(&admin_cap, admin, ctx(s));

            s.return_to_sender(admin_cap);
        };

        s.next_tx(admin);
        let game_id = {
            let game = s.take_from_sender<Game>();
            // check cells

            let num_of_cells = game.num_of_cells();
            assert!(num_of_cells == 20);

            let mut house_idx = 0;
            num_of_cells.do!<()>(|pos_index| {
                if (pos_index == 0 || pos_index == 5) {
                    assert!(game.cell_contains_with_type<Cell>(pos_index));
                } else if (pos_index == 10 || pos_index == 15) {
                    assert!(game.cell_contains_with_type<ChanceCell>(pos_index));
                } else {
                    assert!(game.cell_contains_with_type<HouseCell>(pos_index));
                    let house_cell = house_cell::borrow_house_cell_from_game(&game, pos_index);
                    test_utils::assert_house_cell_basic(
                        house_cell,
                        option::none(),
                        0,
                        (house_idx as u64).to_string(),
                    );
                    house_idx = house_idx + 1;
                };
            });

            // check balances
            game.players().do!(|player| {
                assert!(game.player_balance<Monopoly>(player).value() == initial_fund);
            });

            let game_id = object::id(&game);

            s.return_to_sender(game);

            game_id
        };

        // check first player recieve TurnCap
        s.next_tx(b);
        {
            let turn_cap = test::take_from_sender<TurnCap>(s);

            assert!(turn_cap.turn_cap_game() == game_id);
            assert!(turn_cap.turn_cap_player() == b);
            assert!(turn_cap.turn_cap_moved_steps() == 0);

            s.return_to_sender(turn_cap);
        };

        (scenario, clock)
    }

    fun breakpoint_1(): (Scenario, Clock) {
        let (mut scenario, mut clock) = setup();
        let (admin, b, c, d, e) = people();
        let s = &mut scenario;

        // === player B turn ===

        // player B starts to play the gmae
        s.next_tx(b);
        {
            let random = s.take_shared<Random>();
            let mut turn_cap = s.take_from_sender<TurnCap>();

            // 1) roll the dice
            let moved_steps = turn_cap.player_move(&random, ctx(s));
            assert!(moved_steps == 9);

            test::return_shared(random);
        };

        // server resolve the moving action and emit ActionRequest
        s.next_tx(admin);
        let game_id = {
            let mut game = s.take_from_sender<Game>();
            let turn_cap = s.take_from_address<TurnCap>(object::id_address(&game));

            // we've already known the moved_steps and corresponding action then, therefore we can config the PTB for requried generic parameters
            let mut action_request = game.request_player_move_for_testing<
                Monopoly,
                BuyArgument<Monopoly>,
            >(
                turn_cap,
                ctx(s),
            );
            action_request.initialize_buy_params(&mut game);
            game.request_player_action(action_request);
            let game_id = object::id(&game);

            s.return_to_sender(game);

            game_id
        };

        // player_b acquires ActionRequest and executee "buy_action" by required parameters
        s.next_tx(b);
        {
            let action_request = s.take_from_sender<ActionRequest<BuyArgument<Monopoly>>>();
            let (game_id_, player, new_pos_idx) = action_request.action_request_info();

            // check action_request info
            assert!(game_id == game_id_);
            assert!(player == b);
            assert!(new_pos_idx == 9);
            assert!(action_request.action_request_settled() == false);
            // checkw dynamic argument
            let buy_argument_opt = action_request.action_request_parameters<
                BuyArgument<Monopoly>,
            >();
            assert!(buy_argument_opt.is_some());

            let buy_argument = buy_argument_opt.borrow();
            let (
                type_name,
                player_balance,
                house_price,
                level,
                purchased,
            ) = buy_argument.buy_argument_info();
            assert!(type_name == type_name::get<Monopoly>());
            assert!(player_balance == 2000);
            assert!(house_price == 60);
            assert!(level == 0);
            assert!(purchased == false);

            // settle action request then send the respone back to server
            let payment = 70;
            // action request has been sent to game object
            action_request.execute_buy_action(true, ctx(s));
        };

        s.next_tx(admin);
        {
            let mut game = s.take_from_sender<Game>();

            let action_request = s.take_from_address<ActionRequest<BuyArgument<Monopoly>>>(
                object::id_address(&game),
            );
            let buy_argument_opt = action_request.action_request_parameters();

            assert!(buy_argument_opt.is_some());

            let buy_argument = buy_argument_opt.borrow();
            let (
                type_name,
                player_balance,
                house_price,
                level,
                purchased,
            ) = buy_argument.buy_argument_info();
            assert!(type_name == type_name::get<Monopoly>());
            assert!(player_balance == 2000);
            assert!(house_price == 60);
            assert!(level == 0);
            assert!(purchased == true);
            // server settled buy action state
            house_cell::settle_buy_for_testing(action_request, &mut game, ctx(s));
            // check player balance, house, pos_index
            let player_balance = game.player_balance<Monopoly>(b).value();
            assert!(player_balance == 2000 - 60);
            assert!(game.player_position_of(b) == 9);

            let house_cell: &HouseCell = game.borrow_cell<HouseCell>(9);
            assert!(house_cell.house_cell_owner().extract() == b);
            assert!(house_cell.level() == 1);

            assert!(game.current_round() == 0);
            assert!(game.plays() == 1);

            s.return_to_sender(game);
        };

        // === player C turn ===

        // player C starts next round
        s.next_tx(c);
        {
            let random = s.take_shared<Random>();
            let mut turn_cap = s.take_from_sender<TurnCap>();

            // 1) roll the dice
            let moved_steps = turn_cap.player_move(&random, ctx(s));
            assert!(moved_steps == 4);

            test::return_shared(random);
        };

        s.next_tx(admin);
        let game_id = {
            let mut game = s.take_from_sender<Game>();
            let turn_cap = s.take_from_address<TurnCap>(object::id_address(&game));

            let mut action_request = game.request_player_move_for_testing<
                Monopoly,
                BuyArgument<Monopoly>,
            >(
                turn_cap,
                ctx(s),
            );
            action_request.initialize_buy_params(&mut game);
            game.request_player_action(action_request);
            let game_id = object::id(&game);

            s.return_to_sender(game);

            game_id
        };

        s.next_tx(c);
        {
            let action_request = s.take_from_sender<ActionRequest<BuyArgument<Monopoly>>>();
            let (game_id_, player, new_pos_idx) = action_request.action_request_info();

            // check action_request info
            assert!(game_id == game_id_);
            assert!(player == c);
            assert!(new_pos_idx == 4);
            assert!(action_request.action_request_settled() == false);
            // checkw dynamic argument
            let buy_argument_opt = action_request.action_request_parameters<
                BuyArgument<Monopoly>,
            >();
            assert!(buy_argument_opt.is_some());

            let buy_argument = buy_argument_opt.borrow();
            let (
                type_name,
                player_balance,
                house_price,
                level,
                purchased,
            ) = buy_argument.buy_argument_info();
            assert!(type_name == type_name::get<Monopoly>());
            assert!(player_balance == 2000);
            assert!(house_price == 30);
            assert!(level == 0);
            assert!(purchased == false);

            // player_c refuse to buy
            action_request.execute_buy_action(false, ctx(s));
        };

        s.next_tx(admin);
        {
            let mut game = s.take_from_sender<Game>();

            let action_request = s.take_from_address<ActionRequest<BuyArgument<Monopoly>>>(
                object::id_address(&game),
            );
            let buy_argument_opt = action_request.action_request_parameters();

            assert!(buy_argument_opt.is_some());

            let buy_argument = buy_argument_opt.borrow();
            let (
                type_name,
                player_balance,
                house_price,
                level,
                purchased,
            ) = buy_argument.buy_argument_info();
            assert!(type_name == type_name::get<Monopoly>());
            assert!(player_balance == 2000);
            assert!(house_price == 30);
            assert!(level == 0);
            assert!(purchased == false);
            // server settled buy action state
            house_cell::settle_buy_for_testing(action_request, &mut game, ctx(s));

            // game state

            // check player balance, house, pos_index
            let player_balance = game.player_balance<Monopoly>(c).value();
            // player balance unchanged
            assert!(player_balance == 2000 - 0);
            assert!(game.player_position_of(c) == 4);

            let house_cell: &HouseCell = game.borrow_cell<HouseCell>(4);
            // house_info remains
            assert!(house_cell.house_cell_owner().is_none());
            assert!(house_cell.level() == 0);

            assert!(game.current_round() == 0);
            assert!(game.plays() == 2);

            s.return_to_sender(game);
        };

        // === player D turn ===

        s.next_tx(d);
        {
            let random = s.take_shared<Random>();
            let mut turn_cap = s.take_from_sender<TurnCap>();

            // 1) roll the dice
            let moved_steps = turn_cap.player_move(&random, ctx(s));
            assert!(moved_steps == 10);

            test::return_shared(random);
        };

        s.next_tx(admin);
        let game_id = {
            let random = s.take_shared<Random>();
            let admin_cap = s.take_from_sender<AdminCap>();
            let mut game = s.take_from_sender<Game>();
            let turn_cap = s.take_from_address<TurnCap>(object::id_address(&game));
            let chance_registry = s.take_shared<chance_cell::ChanceRegistry>();

            let request = game.request_player_move_for_testing<Monopoly, ChanceArgument>(
                turn_cap,
                ctx(s),
            );
            let idx = 0;
            chance_cell::initialize_chance_argument_for_testing(
                request,
                &mut game,
                &chance_registry,
                idx,
                ctx(s),
            );

            assert!(
                game.borrow_cell<HouseCell>(house_cell::house_position_of(&game, 3u64.to_string())  as u64).level() == 0,
            );

            assert!(game.player_position_of(d) == 10);
            assert!(game.current_round() == 0);
            assert!(game.plays() == 3);
            assert!(game.player_balance<Monopoly>(d).value() == 2000 + 1000);

            s.return_to_sender(game);
            test::return_shared(random);
            s.return_to_sender(admin_cap);
            test::return_shared(chance_registry);

            game_id
        };

        // === player E turn ===

        s.next_tx(e);
        {
            let random = s.take_shared<Random>();
            let mut turn_cap = s.take_from_sender<TurnCap>();

            // 1) roll the dice
            let moved_steps = turn_cap.player_move(&random, ctx(s));
            assert!(moved_steps == 3);

            test::return_shared(random);
        };

        s.next_tx(admin);
        let game_id = {
            let mut game = s.take_from_sender<Game>();
            let turn_cap = s.take_from_address<TurnCap>(object::id_address(&game));

            let mut action_request = game.request_player_move_for_testing<
                Monopoly,
                BuyArgument<Monopoly>,
            >(
                turn_cap,
                ctx(s),
            );
            action_request.initialize_buy_params(&mut game);
            game.request_player_action(action_request);
            let game_id = object::id(&game);

            s.return_to_sender(game);

            game_id
        };

        s.next_tx(e);
        {
            let action_request = s.take_from_sender<ActionRequest<BuyArgument<Monopoly>>>();
            let (game_id_, player, new_pos_idx) = action_request.action_request_info();

            // check action_request info
            assert!(game_id == game_id_);
            assert!(player == e);
            assert!(new_pos_idx == 3);
            assert!(action_request.action_request_settled() == false);
            // checkw dynamic argument
            let buy_argument_opt = action_request.action_request_parameters<
                BuyArgument<Monopoly>,
            >();
            assert!(buy_argument_opt.is_some());

            let buy_argument = buy_argument_opt.borrow();
            let (
                type_name,
                player_balance,
                house_price,
                level,
                purchased,
            ) = buy_argument.buy_argument_info();
            assert!(type_name == type_name::get<Monopoly>());
            assert!(player_balance == 2000);
            assert!(house_price == 30);
            assert!(level == 0);
            assert!(purchased == false);

            // player_c refuse to buy
            action_request.execute_buy_action(true, ctx(s));
        };

        s.next_tx(admin);
        {
            let mut game = s.take_from_sender<Game>();

            let action_request = s.take_from_address<ActionRequest<BuyArgument<Monopoly>>>(
                object::id_address(&game),
            );
            let buy_argument_opt = action_request.action_request_parameters();

            assert!(buy_argument_opt.is_some());

            let buy_argument = buy_argument_opt.borrow();
            let (
                type_name,
                player_balance,
                house_price,
                level,
                purchased,
            ) = buy_argument.buy_argument_info();
            assert!(type_name == type_name::get<Monopoly>());
            assert!(player_balance == 2000);
            assert!(house_price == 30);
            assert!(level == 0);
            assert!(purchased == true);
            // server settled buy action state
            house_cell::settle_buy_for_testing(action_request, &mut game, ctx(s));
            // check player balance, house, pos_index
            let player_balance = game.player_balance<Monopoly>(e).value();
            assert!(player_balance == 2000 - 30);
            assert!(game.player_position_of(e) == 3);

            let house_cell: &HouseCell = game.borrow_cell<HouseCell>(3);
            assert!(house_cell.house_cell_owner().extract() == e);
            assert!(house_cell.level() == 1);

            assert!(game.current_round() == 1);
            assert!(game.plays() == 4);

            s.return_to_sender(game);
        };

        // === player B turn ===

        s.next_tx(b);
        {
            let random = s.take_shared<Random>();
            let mut turn_cap = s.take_from_sender<TurnCap>();

            // 1) roll the dice
            let moved_steps = turn_cap.player_move(&random, ctx(s));
            assert!(moved_steps == 1);

            test::return_shared(random);
        };

        s.next_tx(admin);
        let game_id = {
            let mut game = s.take_from_sender<Game>();
            let turn_cap = s.take_from_address<TurnCap>(object::id_address(&game));
            let random = s.take_shared<Random>();
            let admin_cap = s.take_from_sender<AdminCap>();
            let chance_registry = s.take_shared<chance_cell::ChanceRegistry>();

            let request = game.request_player_move_for_testing<Monopoly, ChanceArgument>(
                turn_cap,
                ctx(s),
            );
            let idx = 9;
            chance_cell::initialize_chance_argument_for_testing(
                request,
                &mut game,
                &chance_registry,
                idx,
                ctx(s),
            );

            assert!(game.player_position_of(b) == 10);
            assert!(game.current_round() == 1);
            assert!(game.plays() == 5);

            assert!(idx == 9);

            s.return_to_sender(game);
            test::return_shared(random);
            s.return_to_sender(admin_cap);
            test::return_shared(chance_registry);

            game_id
        };

        // === player C turn ===

        s.next_tx(c);
        {
            let random = s.take_shared<Random>();
            let mut turn_cap = s.take_from_sender<TurnCap>();

            let moved_steps = turn_cap.player_move_for_testing(11);
            assert!(moved_steps == 11);

            test::return_shared(random);
        };

        s.next_tx(admin);
        let game_id = {
            let mut game = s.take_from_sender<Game>();
            let turn_cap = s.take_from_address<TurnCap>(object::id_address(&game));
            let random = s.take_shared<Random>();
            let admin_cap = s.take_from_sender<AdminCap>();
            let chance_registry = s.take_shared<chance_cell::ChanceRegistry>();

            let request = game.request_player_move_for_testing<Monopoly, ChanceArgument>(
                turn_cap,
                ctx(s),
            );
            let idx = 57;
            chance_cell::initialize_chance_argument_for_testing(
                request,
                &mut game,
                &chance_registry,
                idx,
                ctx(s),
            );
            assert!(game.player_position_of(c) == 15);
            assert!(game.current_round() == 1);
            assert!(game.plays() == 6);
            assert!(idx == 57);

            assert!(
                game.borrow_cell<HouseCell>(house_cell::house_position_of(&game, 7u64.to_string())  as u64).level() == 2,
            );

            s.return_to_sender(game);
            test::return_shared(random);
            s.return_to_sender(admin_cap);
            test::return_shared(chance_registry);

            game_id
        };

        // === player D turn ===

        s.next_tx(d);
        {
            let random = s.take_shared<Random>();
            let mut turn_cap = s.take_from_sender<TurnCap>();

            let moved_steps = turn_cap.player_move(&random, ctx(s));
            assert!(moved_steps == 5);

            test::return_shared(random);
        };

        s.next_tx(admin);
        let game_id = {
            let mut game = s.take_from_sender<Game>();
            let turn_cap = s.take_from_address<TurnCap>(object::id_address(&game));
            let random = s.take_shared<Random>();
            let admin_cap = s.take_from_sender<AdminCap>();
            let chance_registry = s.take_shared<chance_cell::ChanceRegistry>();

            let request = game.request_player_move_for_testing<Monopoly, ChanceArgument>(
                turn_cap,
                ctx(s),
            );
            let idx = 46;
            chance_cell::initialize_chance_argument_for_testing(
                request,
                &mut game,
                &chance_registry,
                idx,
                ctx(s),
            );

            assert!(game.player_position_of(d) == 15);
            assert!(game.current_round() == 1);
            assert!(game.plays() == 7);
            assert!(idx == 46);

            s.return_to_sender(game);
            test::return_shared(random);
            s.return_to_sender(admin_cap);
            test::return_shared(chance_registry);

            game_id
        };

        s.next_tx(e);
        {
            let random = s.take_shared<Random>();
            let mut turn_cap = s.take_from_sender<TurnCap>();

            let moved_steps = turn_cap.player_move(&random, ctx(s));
            assert!(moved_steps == 10);

            test::return_shared(random);
        };

        s.next_tx(admin);
        let game_id = {
            let mut game = s.take_from_sender<Game>();
            let turn_cap = s.take_from_address<TurnCap>(object::id_address(&game));

            let mut action_request = game.request_player_move_for_testing<
                Monopoly,
                BuyArgument<Monopoly>,
            >(
                turn_cap,
                ctx(s),
            );
            action_request.initialize_buy_params(&mut game);
            game.request_player_action(action_request);
            let game_id = object::id(&game);

            s.return_to_sender(game);

            game_id
        };

        s.next_tx(e);
        {
            let action_request = s.take_from_sender<ActionRequest<BuyArgument<Monopoly>>>();
            let (game_id_, player, new_pos_idx) = action_request.action_request_info();
            // check action_request info
            assert!(game_id == game_id_);
            assert!(player == e);
            assert!(new_pos_idx == 13);
            assert!(action_request.action_request_settled() == false);
            // checkw dynamic argument
            let buy_argument_opt = action_request.action_request_parameters<
                BuyArgument<Monopoly>,
            >();
            assert!(buy_argument_opt.is_some());

            let buy_argument = buy_argument_opt.borrow();
            let (
                type_name,
                player_balance,
                house_price,
                level,
                purchased,
            ) = buy_argument.buy_argument_info();

            assert!(type_name == type_name::get<Monopoly>());
            assert!(player_balance == 2000 - 30);
            assert!(house_price == 80);
            assert!(level == 0);
            assert!(purchased == false);

            // player_c refuse to buy
            action_request.execute_buy_action(true, ctx(s));
        };

        s.next_tx(admin);
        {
            let mut game = s.take_from_sender<Game>();

            let action_request = s.take_from_address<ActionRequest<BuyArgument<Monopoly>>>(
                object::id_address(&game),
            );
            let buy_argument_opt = action_request.action_request_parameters();

            assert!(buy_argument_opt.is_some());

            let buy_argument = buy_argument_opt.borrow();
            let (
                type_name,
                player_balance,
                house_price,
                level,
                purchased,
            ) = buy_argument.buy_argument_info();

            assert!(type_name == type_name::get<Monopoly>());
            assert!(player_balance == 2000 - 30);
            assert!(house_price == 80);
            assert!(level == 0);
            assert!(purchased == true);
            // server settled buy action state
            house_cell::settle_buy_for_testing(action_request, &mut game, ctx(s));
            // check player balance, house, pos_index
            let player_balance = game.player_balance<Monopoly>(e).value();

            assert!(player_balance == 2000 - 30 - 80);
            assert!(game.player_position_of(e) == 13);

            let house_cell: &HouseCell = game.borrow_cell<HouseCell>(13);
            assert!(house_cell.house_cell_owner().extract() == e);
            assert!(house_cell.level() == 1);

            assert!(game.current_round() == 2);
            assert!(game.plays() == 8);

            s.return_to_sender(game);
        };

        // === player B turn ===

        s.next_tx(b);
        {
            let random = s.take_shared<Random>();
            let mut turn_cap = s.take_from_sender<TurnCap>();

            let moved_steps = turn_cap.player_move_for_testing(12);
            assert!(moved_steps == 12);

            test::return_shared(random);
        };

        s.next_tx(admin);

        let game_id = {
            let mut game = s.take_from_sender<Game>();
            let turn_cap = s.take_from_address<TurnCap>(object::id_address(&game));

            // player_b pay "135" toll to player_e
            let mut action_request = game.request_player_move_for_testing<
                Monopoly,
                BuyArgument<Monopoly>,
            >(
                turn_cap,
                ctx(s),
            );

            action_request.initialize_buy_params(&mut game);

            game.request_player_action(action_request);
            let game_id = object::id(&game);

            // player_balance;

            s.return_to_sender(game);

            game_id
        };

        s.next_tx(b);
        {
            let action_request = s.take_from_sender<ActionRequest<BuyArgument<Monopoly>>>();
            let (game_id_, player, new_pos_idx) = action_request.action_request_info();
            // check action_request info
            assert!(game_id == game_id_);
            assert!(player == b);
            assert!(new_pos_idx == 2);
            assert!(action_request.action_request_settled() == false);
            // checkw dynamic argument
            let buy_argument_opt = action_request.action_request_parameters<
                BuyArgument<Monopoly>,
            >();
            assert!(buy_argument_opt.is_some());

            let buy_argument = buy_argument_opt.borrow();
            let (
                type_name,
                player_balance,
                house_price,
                level,
                purchased,
            ) = buy_argument.buy_argument_info();

            assert!(type_name == type_name::get<Monopoly>());
            assert!(player_balance == 2040);
            assert!(house_price == 20);
            assert!(level == 0);
            assert!(purchased == false);

            action_request.execute_buy_action(true, ctx(s));
        };

        s.next_tx(admin);
        {
            let mut game = s.take_from_sender<Game>();

            let action_request = s.take_from_address<ActionRequest<BuyArgument<Monopoly>>>(
                object::id_address(&game),
            );
            let buy_argument_opt = action_request.action_request_parameters();

            assert!(buy_argument_opt.is_some());

            let buy_argument = buy_argument_opt.borrow();
            let (
                type_name,
                player_balance,
                house_price,
                level,
                purchased,
            ) = buy_argument.buy_argument_info();

            assert!(type_name == type_name::get<Monopoly>());
            assert!(player_balance == 2040);
            assert!(house_price == 20);
            assert!(level == 0);
            assert!(purchased == true);
            // server settled buy action state
            house_cell::settle_buy_for_testing(action_request, &mut game, ctx(s));
            // check player balance, house, pos_index
            let player_balance = game.player_balance<Monopoly>(b).value();
            assert!(player_balance == 2040 - 20);
            assert!(game.player_position_of(b) == 2);

            let house_cell: &HouseCell = game.borrow_cell<HouseCell>(2);
            assert!(house_cell.house_cell_owner().extract() == b);
            assert!(house_cell.level() == 1);

            assert!(game.current_round() == 2);
            assert!(game.plays() == 9);

            s.return_to_sender(game);
        };

        (scenario, clock)
    }

    fun breakpoint_2(): (Scenario, Clock) {
        let (mut scenario, mut clock) = breakpoint_1();
        let (admin, b, c, d, e) = people();
        let s = &mut scenario;

        // === player C turn ===

        s.next_tx(c);
        {
            let random = s.take_shared<Random>();
            let mut turn_cap = s.take_from_sender<TurnCap>();

            let moved_steps = turn_cap.player_move_for_testing(3);
            assert!(moved_steps == 3);

            test::return_shared(random);
        };

        s.next_tx(admin);
        let game_id = {
            let mut game = s.take_from_sender<Game>();
            let turn_cap = s.take_from_address<TurnCap>(object::id_address(&game));

            let mut action_request = game.request_player_move_for_testing<
                Monopoly,
                BuyArgument<Monopoly>,
            >(
                turn_cap,
                ctx(s),
            );

            action_request.initialize_buy_params(&mut game);

            game.request_player_action(action_request);
            let game_id = object::id(&game);

            s.return_to_sender(game);

            game_id
        };
        s.next_tx(c);
        {
            let action_request = s.take_from_sender<ActionRequest<BuyArgument<Monopoly>>>();
            let (game_id_, player, new_pos_idx) = action_request.action_request_info();
            // check action_request info
            assert!(game_id == game_id_);
            assert!(player == c);
            assert!(new_pos_idx == 18);
            assert!(action_request.action_request_settled() == false);
            // checkw dynamic argument
            let buy_argument_opt = action_request.action_request_parameters<
                BuyArgument<Monopoly>,
            >();
            assert!(buy_argument_opt.is_some());

            let buy_argument = buy_argument_opt.borrow();
            let (
                type_name,
                player_balance,
                house_price,
                level,
                purchased,
            ) = buy_argument.buy_argument_info();

            assert!(type_name == type_name::get<Monopoly>());
            assert!(player_balance == 2000);
            assert!(house_price == 110);
            assert!(level == 0);
            assert!(purchased == false);

            action_request.execute_buy_action(true, ctx(s));
        };

        s.next_tx(admin);
        {
            let mut game = s.take_from_sender<Game>();

            let action_request = s.take_from_address<ActionRequest<BuyArgument<Monopoly>>>(
                object::id_address(&game),
            );
            let buy_argument_opt = action_request.action_request_parameters();

            assert!(buy_argument_opt.is_some());

            let buy_argument = buy_argument_opt.borrow();
            let (
                type_name,
                player_balance,
                house_price,
                level,
                purchased,
            ) = buy_argument.buy_argument_info();

            assert!(type_name == type_name::get<Monopoly>());
            assert!(player_balance == 2000);
            assert!(house_price == 110);
            assert!(level == 0);
            assert!(purchased == true);
            // server settled buy action state
            house_cell::settle_buy_for_testing(action_request, &mut game, ctx(s));
            // check player balance, house, pos_index
            let player_balance = game.player_balance<Monopoly>(c).value();
            assert!(player_balance == 2000 - 110);
            assert!(game.player_position_of(c) == 18);

            let house_cell: &HouseCell = game.borrow_cell<HouseCell>(18);
            assert!(house_cell.house_cell_owner().extract() == c);
            assert!(house_cell.level() == 1);

            assert!(game.current_round() == 2);
            assert!(game.plays() == 10);

            s.return_to_sender(game);
        };

        // === player D turn ===

        s.next_tx(d);
        {
            let random = s.take_shared<Random>();
            let mut turn_cap = s.take_from_sender<TurnCap>();

            let moved_steps = turn_cap.player_move_for_testing(3);
            assert!(moved_steps == 3);

            test::return_shared(random);
        };

        s.next_tx(admin);
        let game_id = {
            let mut game = s.take_from_sender<Game>();
            let turn_cap = s.take_from_address<TurnCap>(object::id_address(&game));

            let mut action_request = game.request_player_move_for_testing<
                Monopoly,
                BuyArgument<Monopoly>,
            >(
                turn_cap,
                ctx(s),
            );
            action_request.initialize_buy_params(&mut game);
            game.drop_action_request(action_request, ctx(s));

            assert!(game.player_position_of(d) == 18);
            assert!(game.current_round() == 2);
            assert!(game.plays() == 11);

            // player_balance;
            assert!(game.player_balance<Monopoly>(c).value() == 2000 - 110 + 165);
            assert!(game.player_balance<Monopoly>(d).value() == 3000 - 165);

            s.return_to_sender(game);

            game_id
        };

        // === player E turn ===

        s.next_tx(e);
        {
            let random = s.take_shared<Random>();
            let mut turn_cap = s.take_from_sender<TurnCap>();

            let moved_steps = turn_cap.player_move_for_testing(20);
            assert!(moved_steps == 20);

            test::return_shared(random);
        };

        s.next_tx(admin);
        let game_id = {
            // upgrade to the max level
            let mut game = s.take_from_sender<Game>();
            let turn_cap = s.take_from_address<TurnCap>(object::id_address(&game));

            let mut action_request = game.request_player_move_for_testing<
                Monopoly,
                BuyArgument<Monopoly>,
            >(
                turn_cap,
                ctx(s),
            );
            action_request.initialize_buy_params(&mut game);
            game.request_player_action(action_request);
            let game_id = object::id(&game);

            // we won't recieve salary as we're cheating :p
            assert!(game.player_balance<Monopoly>(e).value() == 1890);

            s.return_to_sender(game);

            game_id
        };

        s.next_tx(e);
        {
            let action_request = s.take_from_sender<ActionRequest<BuyArgument<Monopoly>>>();
            let (game_id_, player, new_pos_idx) = action_request.action_request_info();

            // check action_request info
            assert!(game_id == game_id_);
            assert!(player == e);
            assert!(new_pos_idx == 13);
            assert!(action_request.action_request_settled() == false);
            // checkw dynamic argument
            let buy_argument_opt = action_request.action_request_parameters<
                BuyArgument<Monopoly>,
            >();
            assert!(buy_argument_opt.is_some());

            let buy_argument = buy_argument_opt.borrow();
            let (
                type_name,
                player_balance,
                house_price,
                level,
                purchased,
            ) = buy_argument.buy_argument_info();
            assert!(type_name == type_name::get<Monopoly>());
            assert!(player_balance == 1890);
            assert!(house_price == 220);
            assert!(level == 1);
            assert!(purchased == false);

            action_request.execute_buy_action(true, ctx(s));
        };

        s.next_tx(admin);
        {
            let mut game = s.take_from_sender<Game>();

            let action_request = s.take_from_address<ActionRequest<BuyArgument<Monopoly>>>(
                object::id_address(&game),
            );
            let buy_argument_opt = action_request.action_request_parameters();

            assert!(buy_argument_opt.is_some());

            let buy_argument = buy_argument_opt.borrow();
            let (
                type_name,
                player_balance,
                house_price,
                level,
                purchased,
            ) = buy_argument.buy_argument_info();
            assert!(type_name == type_name::get<Monopoly>());
            assert!(player_balance == 1890);
            assert!(house_price == 220);
            assert!(level == 1);
            assert!(purchased == true);
            // server settled buy action state
            house_cell::settle_buy_for_testing(action_request, &mut game, ctx(s));
            // check player balance, house, pos_index
            let player_balance = game.player_balance<Monopoly>(e).value();
            assert!(player_balance == 1890 - 220);
            assert!(game.player_position_of(e) == 13);

            let house_cell: &HouseCell = game.borrow_cell<HouseCell>(13);
            assert!(house_cell.house_cell_owner().extract() == e);
            assert!(house_cell.level() == 2);
            assert!(game.current_round() == 3);
            assert!(game.plays() == 12);

            s.return_to_sender(game);
        };

        // === player B turn ===

        s.next_tx(b);
        {
            // make player_b bankrupt
            let random = s.take_shared<Random>();
            let mut turn_cap = s.take_from_sender<TurnCap>();

            let moved_steps = turn_cap.player_move_for_testing(20);
            assert!(moved_steps == 20);

            test::return_shared(random);
        };

        s.next_tx(admin);
        let game_id = {
            // upgrade to the max level
            let mut game = s.take_from_sender<Game>();
            let turn_cap = s.take_from_address<TurnCap>(object::id_address(&game));

            let mut action_request = game.request_player_move_for_testing<
                Monopoly,
                BuyArgument<Monopoly>,
            >(
                turn_cap,
                ctx(s),
            );
            action_request.initialize_buy_params(&mut game);
            game.request_player_action(action_request);
            let game_id = object::id(&game);
            // we won't recieve salary as we're cheating :p
            assert!(game.player_balance<Monopoly>(b).value() == 2020);

            s.return_to_sender(game);

            game_id
        };

        s.next_tx(b);
        {
            let action_request = s.take_from_sender<ActionRequest<BuyArgument<Monopoly>>>();
            let (game_id_, player, new_pos_idx) = action_request.action_request_info();

            // check action_request info
            assert!(game_id == game_id_);
            assert!(player == b);
            assert!(new_pos_idx == 2);
            assert!(action_request.action_request_settled() == false);
            // checkw dynamic argument
            let buy_argument_opt = action_request.action_request_parameters<
                BuyArgument<Monopoly>,
            >();
            assert!(buy_argument_opt.is_some());

            let buy_argument = buy_argument_opt.borrow();
            let (
                type_name,
                player_balance,
                house_price,
                level,
                purchased,
            ) = buy_argument.buy_argument_info();

            assert!(type_name == type_name::get<Monopoly>());
            assert!(player_balance == 2020);
            assert!(house_price == 60);
            assert!(level == 1);
            assert!(purchased == false);

            action_request.execute_buy_action(true, ctx(s));
        };

        s.next_tx(admin);
        {
            let mut game = s.take_from_sender<Game>();

            let action_request = s.take_from_address<ActionRequest<BuyArgument<Monopoly>>>(
                object::id_address(&game),
            );
            let buy_argument_opt = action_request.action_request_parameters();

            assert!(buy_argument_opt.is_some());

            let buy_argument = buy_argument_opt.borrow();
            let (
                type_name,
                player_balance,
                house_price,
                level,
                purchased,
            ) = buy_argument.buy_argument_info();

            assert!(type_name == type_name::get<Monopoly>());
            assert!(player_balance == 2020);
            assert!(house_price == 60);
            assert!(level == 1);
            assert!(purchased == true);
            // server settled buy action state
            house_cell::settle_buy_for_testing(action_request, &mut game, ctx(s));
            // check player balance, house, pos_index
            let player_balance = game.player_balance<Monopoly>(e).value();
            assert!(player_balance == 1890 - 220);
            assert!(game.player_position_of(e) == 13);
            let house_cell: &HouseCell = game.borrow_cell<HouseCell>(2);
            assert!(house_cell.house_cell_owner().extract() == b);
            assert!(house_cell.level() == 2);
            assert!(game.current_round() == 3);
            assert!(game.plays() == 13);

            s.return_to_sender(game);
        };

        // === player C turn ===

        s.next_tx(c);
        {
            // make player_b bankrupt
            let random = s.take_shared<Random>();
            let mut turn_cap = s.take_from_sender<TurnCap>();

            let moved_steps = turn_cap.player_move_for_testing(18);
            assert!(moved_steps == 18);

            test::return_shared(random);
        };
        s.next_tx(admin);
        let game_id = {
            // upgrade to the max level
            let mut game = s.take_from_sender<Game>();
            let turn_cap = s.take_from_address<TurnCap>(object::id_address(&game));

            let mut action_request = game.request_player_move_for_testing<
                Monopoly,
                BuyArgument<Monopoly>,
            >(
                turn_cap,
                ctx(s),
            );
            action_request.initialize_buy_params(&mut game);
            game.request_player_action(action_request);
            let game_id = object::id(&game);
            // we won't recieve salary as we're cheating :p
            assert!(game.player_balance<Monopoly>(c).value() == 2155);

            s.return_to_sender(game);

            game_id
        };

        s.next_tx(c);
        {
            let action_request = s.take_from_sender<ActionRequest<BuyArgument<Monopoly>>>();
            let (game_id_, player, new_pos_idx) = action_request.action_request_info();

            // check action_request info
            assert!(game_id == game_id_);
            assert!(player == c);
            assert!(new_pos_idx == 16);
            assert!(action_request.action_request_settled() == false);
            // checkw dynamic argument
            let buy_argument_opt = action_request.action_request_parameters<
                BuyArgument<Monopoly>,
            >();
            assert!(buy_argument_opt.is_some());

            let buy_argument = buy_argument_opt.borrow();
            let (
                type_name,
                player_balance,
                house_price,
                level,
                purchased,
            ) = buy_argument.buy_argument_info();

            assert!(type_name == type_name::get<Monopoly>());
            assert!(player_balance == 2155);
            assert!(house_price == 90);
            assert!(level == 0);
            assert!(purchased == false);

            action_request.execute_buy_action(true, ctx(s));
        };

        s.next_tx(admin);
        {
            let mut game = s.take_from_sender<Game>();

            let action_request = s.take_from_address<ActionRequest<BuyArgument<Monopoly>>>(
                object::id_address(&game),
            );
            let buy_argument_opt = action_request.action_request_parameters();

            assert!(buy_argument_opt.is_some());

            let buy_argument = buy_argument_opt.borrow();
            let (
                type_name,
                player_balance,
                house_price,
                level,
                purchased,
            ) = buy_argument.buy_argument_info();

            assert!(type_name == type_name::get<Monopoly>());
            assert!(player_balance == 2155);
            assert!(house_price == 90);
            assert!(level == 0);
            assert!(purchased == true);
            // server settled buy action state
            house_cell::settle_buy_for_testing(action_request, &mut game, ctx(s));
            // check player balance, house, pos_index
            let player_balance = game.player_balance<Monopoly>(c).value();
            assert!(player_balance == 2155 - 90);
            assert!(game.player_position_of(c) == 16);
            let house_cell: &HouseCell = game.borrow_cell<HouseCell>(16);
            assert!(house_cell.house_cell_owner().extract() == c);
            assert!(house_cell.level() == 1);

            assert!(game.current_round() == 3);
            assert!(game.plays() == 14);

            s.return_to_sender(game);
        };

        (scenario, clock)
    }

    fun breakpoint_3(): (Scenario, Clock) {
        let (mut scenario, mut clock) = breakpoint_2();
        let (admin, b, c, d, e) = people();
        let s = &mut scenario;

        // === player D turn ===

        s.next_tx(d);
        {
            let random = s.take_shared<Random>();
            let mut turn_cap = s.take_from_sender<TurnCap>();

            let moved_steps = turn_cap.player_move_for_testing(5);
            assert!(moved_steps == 5);

            test::return_shared(random);
        };

        s.next_tx(admin);
        let game_id = {
            let mut game = s.take_from_sender<Game>();
            let game_id = object::id(&game);

            let turn_cap = s.take_from_address<TurnCap>(object::id_address(&game));

            let mut action_request = game.request_player_move_for_testing<
                Monopoly,
                BuyArgument<Monopoly>,
            >(
                turn_cap,
                ctx(s),
            );
            action_request.initialize_buy_params(&mut game);
            game.drop_action_request(action_request, ctx(s));

            assert!(game.player_position_of(d) == 3);
            assert!(game.current_round() == 3);
            assert!(game.plays() == 15);

            // player_balance;
            assert!(game.player_balance<Monopoly>(d).value() == 2835 + 100 - 45);
            assert!(game.player_balance<Monopoly>(e).value() == 1670 + 45);

            s.return_to_sender(game);

            game_id
        };

        (scenario, clock)
    }

    #[test]
    fun test_monopoly_basic() {
        let (mut scenario, mut clock) = breakpoint_3();
        let (admin, b, c, d, e) = people();
        let s = &mut scenario;

        // === player E turn ===

        s.next_tx(e);
        {
            let random = s.take_shared<Random>();
            let mut turn_cap = s.take_from_sender<TurnCap>();

            let moved_steps = turn_cap.player_move_for_testing(20);
            assert!(moved_steps == 20);

            test::return_shared(random);
        };

        s.next_tx(admin);
        let game_id = {
            // upgrade to the max level
            let mut game = s.take_from_sender<Game>();
            let turn_cap = s.take_from_address<TurnCap>(object::id_address(&game));

            let mut action_request = game.request_player_move_for_testing<
                Monopoly,
                BuyArgument<Monopoly>,
            >(
                turn_cap,
                ctx(s),
            );
            action_request.initialize_buy_params(&mut game);
            game.request_player_action(action_request);
            let game_id = object::id(&game);

            assert!(game.player_balance<Monopoly>(e).value() == 1715);

            s.return_to_sender(game);

            game_id
        };

        s.next_tx(e);
        {
            let action_request = s.take_from_sender<ActionRequest<BuyArgument<Monopoly>>>();
            let (game_id_, player, new_pos_idx) = action_request.action_request_info();

            // check action_request info
            assert!(game_id == game_id_);
            assert!(player == e);
            assert!(new_pos_idx == 13);
            assert!(action_request.action_request_settled() == false);
            // checkw dynamic argument
            let buy_argument_opt = action_request.action_request_parameters<
                BuyArgument<Monopoly>,
            >();
            assert!(buy_argument_opt.is_some());

            let buy_argument = buy_argument_opt.borrow();
            let (
                type_name,
                player_balance,
                house_price,
                level,
                purchased,
            ) = buy_argument.buy_argument_info();

            assert!(type_name == type_name::get<Monopoly>());
            assert!(player_balance == 1715);
            assert!(house_price == 600);
            assert!(level == 2);
            assert!(purchased == false);

            action_request.execute_buy_action(true, ctx(s));
        };

        s.next_tx(admin);
        {
            let mut game = s.take_from_sender<Game>();

            let action_request = s.take_from_address<ActionRequest<BuyArgument<Monopoly>>>(
                object::id_address(&game),
            );
            let buy_argument_opt = action_request.action_request_parameters();

            assert!(buy_argument_opt.is_some());

            let buy_argument = buy_argument_opt.borrow();
            let (
                type_name,
                player_balance,
                house_price,
                level,
                purchased,
            ) = buy_argument.buy_argument_info();
            assert!(type_name == type_name::get<Monopoly>());
            assert!(player_balance == 1715);
            assert!(house_price == 600);
            assert!(level == 2);
            assert!(purchased == true);
            // server settled buy action state
            house_cell::settle_buy_for_testing(action_request, &mut game, ctx(s));
            // check player balance, house, pos_index
            let player_balance = game.player_balance<Monopoly>(e).value();
            assert!(player_balance == 1715 - 600);
            assert!(game.player_position_of(e) == 13);

            let house_cell: &HouseCell = game.borrow_cell<HouseCell>(13);
            assert!(house_cell.house_cell_owner().extract() == e);
            assert!(house_cell.level() == 3);

            assert!(game.current_round() == 4);
            assert!(game.plays() == 16);

            s.return_to_sender(game);
        };

        // === Game Finish ===

        s.next_tx(admin);
        {
            let mut game = s.take_from_sender<Game>();

            // remove_balance
            let (supply, balance_info) = game.remove_balance<Monopoly>();
            balance::destroy_supply(supply);

            // remove all the cells
            20u64.do!<u64>(|idx: u64| {
                // cells order
                if (idx == 0 || idx == 5) {
                    let cell: Cell = game.remove_cell(idx);
                    cell.drop_cell();
                } else if (idx == 10 || idx == 15) {
                    let cell: ChanceCell = game.remove_cell(idx);
                    cell.drop_chance_cell();
                } else {
                    let cell: HouseCell = game.remove_cell(idx);
                    cell.drop_house_cell();
                };
            });

            // remove all states
            house_cell::remove_states(&mut game);

            game.drop();
        };

        scenario.end();
        clock.destroy_for_testing();
    }
}

// player_b
// - huoses: [9]

// player_c
// - huoses: [11, 2]

// player_d
// - huoses: []

// player_e
// - huoses: [3, 6]

// positions:[3, 2, 5, 3]
// balances:[1795, 2115, 2000, 1930]
