# Changeban

**TODO: Add description**

1. Create Game in Setup state
1. Invite Players - copy and distribute URL
1. Players join - live view
    joining form - Name and color
1. Create starting position
1. Play Game
    1. Distribute cards
    1. Group discusses
    1. Make moves
    1. Team chooses (if available)
    1. competing all moves activates new day

##  Objective
Players move the items across the board to "accepted" column.

Because we recognise the 10th [Agile Manifesto principle](https://agilemanifesto.org/principles.html) “Simplicity — the art of maximizing the amount of work not done — is essential.” We aim to cancel items where possible.

Because we recognise the value of balancing the delivery features with changing and improving teh way we work we want to accept and cancel items in a balnaced way.

## How the game is played

Setup

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
# Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `changeban` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:changeban, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/changeban](https://hexdocs.pm/changeban).

