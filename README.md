# CHANGEBAN

This is an on-line implementation of the Agendashift workshop of the same name: https://www.agendashift.com/resources/changeban It is designed to be used as part of a workshop but can be played by any group to
get a feel for flow.

# Changeban

1. One person starts a new game and passes the game code to the others
1. The other players join, providing initials so they can visually track items in the game
1. Once all players (five, including the first) have joined one of them should start the game
    1. If anyone tries to join after this they will join as an observer, teh number of pbservers is unlimited.
1. Play Game
    1. New turn and team members see their move type
    1. Team discusses
    1. Team members make moves
    1. Team chooses reject options (if available)
    1. competing all moves activates new turn

##  Objective
Players move the items across the board to "accepted" column.

Because we recognise the 10th [Agile Manifesto principle](https://agilemanifesto.org/principles.html) “Simplicity — the art of maximizing the amount of work not done — is essential.” We aim to reject items where possible.

Because we recognise the value of balancing the delivery features with changing and improving the way we work we want to accept and cancel items in a balanced way.

## How the game is played

### Setup

8 work cards & 8 change cards are placed in the ready column.

### Daily standup meeting

Each player is issued a move type (RED or BLACK)

#### RED
- You MUST MOVE:
  - EITHER:
      move ONE of your unblocked items ONE column right
  - OR:
    unblock ONE of your blocked items
  - OR:
    start ONE new item (if any remain)

#### BLACK
  - YOU MUST BOTH:
    - BLOCK:
      block ONE unblocked item, if you own one
    - AND MOVE:
      start ONE new item (if any remain)

#### BOTH
  If you cannot MOVE, HELP someone!
  Advance or unblock ONE item from another player

#### BOTH
  Whenever an item moves to "Accepted"
  the team can chose ONE other to be rejected (from anyone)

### Starting an Item:
  The item is assigned to the player and moved to the first in-progress column

---
# Getting up and running locally

changeban does not use a database so the setup is pretty easy.

changeban is a simple elixir phoenix app

```bash
git clone https://github.com/BigTom/changeban.git
cd changeban
mix deps.get
cd /assets/
npm install
cd ..
mix phx.server
```

# Testing
Run tests with coverage like this:

```bash
mix test --cover
```
# Deployment

I deploy to gigalixir.com. The config is in the  `config/prod.exs` file.  There are no secrets.
