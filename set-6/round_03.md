# Round 3: Round 3: What runs in the user mind vs system compute

## Question

In a TTRPG, the DM doesn't compute 'does the player see the orc?' The DM runs the perception check, which is retrieval. But the DM improvises the orc's reaction, which is generation. What's the line between retrieval and generation? How does this map to the Quilt substrate's openers? To the Cordis plugin's coeffects? And: when a player's attention is on the game, what runs in the player's mind that doesn't need to run in the system?

## Cast contributions

### Qwen 72B (sensible deep)

### The Line Between Retrieval and Generation in TTRPGs and Quilt

In a TTRPG, the DM's role is multifaceted, involving both retrieval and generation. Retrieval involves accessing pre-defined game state information, such as whether a player can see an orc based on their perception skill. Generation, on the other hand, involves creating new content, such as the orc's reaction to the player's actions. This distinction is crucial for understanding how to design the Quilt substrate and the Cordis plugin.

#### The Primitive: `retrieve_perception` and `generate_reaction`

**Signature:**
```python
def retrieve_perception(user: User, entity: Entity, game_state: GameState) -> bool
def generate_reaction(user: User, entity: Entity, action: Action, game_state: GameState) -> Reaction
```

**Semantics:**
- `retrieve_perception(user, entity, game_state)`: Determines whether the user can see or perceive the entity based on the user's perception skill and the current game state.
- `generate_reaction(user, entity, action, game_state)`: Generates the reaction of the entity to the user's action, considering the entity's personality, the current game state, and the context of the action.

**Example:**
```python
class User:
    def __init__(self, name, perception_skill):
        self.name = name
        self.perception_skill = perception_skill

class Entity:
    def __init__(self, name, location, is_hidden):
        self.name = name
        self.location = location
        self.is_hidden = is_hidden

class GameState:
    def __init__(self, entities, environment):
        self.entities = entities
        self.environment = environment

class Action:
    def __init__(self, type, details):
        self.type = type
        self.details = details

class Reaction:
    def __init__(self, type, details):
        self.type = type
        self.details = details

def retrieve_perception(user: User, entity: Entity, game_state: GameState) -> bool:
    if not entity.is_hidden or user.perception_skill >= 10:
        return True
    return False

def generate_reaction(user: User, entity: Entity, action: Action, game_state: GameState) -> Reaction:
    if action.type == "attack":
        if entity.name == "Orc":
            return Reaction("defend", "The orc raises its shield and growls.")
    return Reaction("ignore", "The orc continues its activity, seemingly unaware.")

# Example usage
user = User("Alice", 12)
orc = Entity("Orc", (10, 10), True)
game_state = GameState(entities=[orc], environment={...})
action = Action("attack", "with a sword")

perception = retrieve_perception(user, orc, game_state)
reaction = generate_reaction(user, orc, action, game_state)
```

#### Mapping to Quilt Substrate's Openers

In the Quilt substrate, openers are responsible for managing the interaction between the user and the game state. The `retrieve_perception` function can be seen as an opener that checks the game state and returns a boolean indicating whether the user can perceive an entity. This opener is used to filter the game state before it is projected to the user.

**Example Openers:**
```python
class PerceptionOpener:
    def __init__(self, user: User, game_state: GameState):
        self.user = user
        self.game_state = game_state

    def open(self, entity: Entity) -> bool:
        return retrieve_perception(self.user, entity, self.game_state)

# Example usage
perception_opener = PerceptionOpener(user, game_state)
visible_entities = [entity for entity in game_state.entities if perception_opener.open(entity)]
```

#### Mapping to Cordis Plugin's Coeffects

The Cordis plugin's coeffects can be used to manage the side effects of user actions, such as generating reactions from entities. The `generate_reaction` function can be seen as a coeffect that modifies the game state based on the user's action.

**Example Coeffect:**
```python
class ReactionCoeffect:
    def __init__(self, user: User, game_state: GameState):
        self.user = user
        self.game_state = game_state

    def apply(self, entity: Entity, action: Action) -> Reaction:
        return generate_reaction(self.user, entity, action, self.game_state)

# Example usage
reaction_coeffect = ReactionCoeffect(user, game_state)
reaction = reaction_coeffect.apply(orc, action)
```

#### Player's Mind vs. System's Computation

When a player's attention is on the game, several cognitive processes run in the player's mind that do not need to be replicated in the system:
1. **Imagination and Visualization**: Players use their imagination to visualize the game world, characters, and events. This can be highly detailed and personalized, which is difficult for the system to replicate.
2. **Strategic Thinking**: Players think strategically about their actions, considering multiple possible outcomes and making decisions based on their goals and the game state. This involves a level of creativity and adaptability that is challenging for a system to fully emulate.
3. **Emotional Engagement**: Players experience emotions such as excitement, fear, and satisfaction, which are deeply personal and context-dependent. The system can facilitate these emotions but cannot fully generate or control them.

### CONTRIBUTIONS:
- Defined the `retrieve_perception` and `generate_reaction` primitives for TTRPG-like interactions.
- Mapped these primitives to the Quilt substrate's openers and the Cordis plugin's coeffects.
- Highlighted the cognitive processes in the player's mind that do not need to be replicated in the system.

### RECOMMENDATIONS:
- Implement advanced AI techniques for generating realistic and varied reactions from entities.
- Develop user interface elements that enhance the player's imagination and strategic thinking without overwhelming them with information.
- Test the system with a diverse group of users to ensure that it effectively supports the cognitive processes involved in TTRPGs.

### OPEN QUESTIONS:
1. How can the system dynamically adjust the level of detail in the game state based on the player's current focus and cognitive load?
2. What are the best practices for balancing the use of AI-generated content with player-driven creativity in TTRPG-like games?
3. How can the system handle the asynchronous nature of player actions and the synchronous progression of the game state to ensure a seamless user experience?

---

### Hermes 405B (long-form surprise)

The distinction between retrieval and generation lies in the nature of the information being processed and the cognitive effort required. Retrieval involves accessing pre-existing information, such as the current state of the game world, the properties of objects and NPCs, and the rules governing their interactions. Generation, on the other hand, involves creating new information based on the retrieved data, such as improvising the orc's reaction to the player's actions.

In the context of the Quilt substrate's openers and the Cordis plugin's coeffects, retrieval corresponds to accessing the relevant portions of the game state and the rules that govern it. The Quilt substrate provides the necessary data structures and algorithms for efficiently storing and retrieving this information, while the Cordis plugin's coeffects allow for the composition of multiple rules and actions.

Generation, in this context, corresponds to the application of these rules and the creation of new game states based on the retrieved information and the players' actions. The Quilt substrate's openers provide the means for defining and executing these generative processes, while the Cordis plugin's coeffects enable the combination of multiple effects and the handling of their interactions.

When a player's attention is focused on the game, their mind is engaged in a process of sensemaking and decision-making. They are interpreting the information presented to them, forming mental models of the game world, and making choices based on their goals and the available options. This process is inherently subjective and context-dependent, and does not need to be fully replicated in the system.

Instead, the system should focus on providing the necessary information and affordances for the player to engage in this process, while handling the retrieval and generation aspects that are not directly tied to the player's subjective experience. This includes maintaining the consistency and coherence of the game world, managing the interactions between objects and NPCs, and providing feedback and consequences for the player's actions.

CONTRIBUTIONS:
- Clarified the distinction between retrieval and generation in the context of TTRPGs and the Quilt/Cordis architecture.
- Identified the mapping between retrieval/generation and the Quilt substrate's openers and the Cordis plugin's coeffects.
- Discussed the role of the player's mind in sensemaking and decision-making, and its implications for the system's design.

RECOMMENDATIONS:
- Explore techniques for efficiently representing and retrieving game state information, such as spatial databases and caching/prefetching.
- Investigate methods for composing and executing generative processes, such as the Quilt substrate's openers and the Cordis plugin's coeffects.
- Consider the trade-offs between the system's responsibility for retrieval/generation and the player's subjective experience, and design the architecture accordingly.

OPEN QUESTIONS:
- How can the system adapt to different players' sensemaking and decision-making styles, and provide personalized support and feedback?
- What are the limits of the system's ability to generate coherent and engaging game experiences, and how can these limits be pushed or worked around?
- How can the architecture support the integration of player-generated content and emergent narratives, while maintaining the consistency and coherence of the game world?

---

