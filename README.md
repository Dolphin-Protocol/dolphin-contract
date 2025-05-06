# 🧩 Monopoly Smart Contract on Sui

This is a Move-based smart contract that realize fully onchain Monopoly board game on the Sui blockchain to call attention to Sui's exceptional performance and efficiency. It allows players to join a game, roll dice, move across a virtual board, buy property, and manage turns using programmable logic and on-chain assets with composable feature that extends any dynamic configuration.

---

## 🏛 Architecture Overview

The system is composed of several key modules and comply to Sui's P2P methodology to follow owned object pattern to achieve high efficiency and fast onchain settlment

- **`monopoly::monopoly`** – Main game engine: handles game creation, joining, turn management, and action resolution.
- **`cells`** – Represents individual board positions (cells) in the game
    - **`normal cell`** – Represents individual board positions (cells).
    - **`house_cell`** – Special cell type for house properties that can be purchased and upgraded.
    - **`chance_cell`** – Special cell type for players drawing cards that affect their game
- **`balance` / `balance_manager`** – Manages in-game currency and player accounts.

---

## 📦 Core Objects

### `Game`
Represents the game state, including:
- Players and their positions
- Board layout (cells)
- Turn order
- Game configuration and rules

### `TurnCap`
A capability that gives a player the right to act during their turn.

### `ActionRequest`
Encapsulates player intentions like rolling dice or buying a property.

### `AdminCap`
Grants game management rights to its creator (admin).

---

## 🔄 Game Flow

1. **Game Initialization**
   - Admin deploys a `Game` with custom cells and desired parameters like players, rounds..etc
   - Turn cap is provided once game initialization then transferred to next player

2. **Turn Execution**
   - Player holding `TurnCap` represent active player to roll the dice, the dice will be rolled once player send the TurnCap back to game engine
   - If player's goes to the cell with customized actions, it will submits an `ActionRequest` to player to continue further logic then transfer back to game engine to express the intentions
   - Game engine resolves the request (e.g., dice roll and movement).
   - Player may land on different cell types:
     - `DoNothing` – Pass-through
     - `HouseCell` – Can buy/upgrade property
     - `ChanceCell` – generate random scenario affecting the game

3. **Next Turn**
   - After resolution, `TurnCap` is passed to the next player.

---

## 🔁 Interaction Graph

```mermaid
graph TD
    A[Admin] -->|create_game| B(Game)
    B --> A
    C[Player] -->|roll dice & move| D(TurnCap)
    D --> |resolve| B[Game]
    C -->|land on cell| E[Cell Logic]
    E --> E1[HouseCell]
    E --> E2[EmptyCell]
    E --> E3[ChanceCell]
    
    E1 -->|emit ActionRequest| F[ActionRequest]
    E2 -->|nothing happenes| H[DoNothing]
    E3 --> |trigger random action| H[DoNothing]

    F -->|player responds| G[Resolve Action]
    G -->|update state| B1(HouseCell)
    B1 --> B
    G -->|pass TurnCap| C2[Next Player]

    H -->|pass TurnCap| C2

