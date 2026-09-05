# Round 2: Round 2: Async IO with sync game

## Question

The user gave us: 'asynchronous IO with a synchronous game happening is the core of Quilt.' This was true of MUDs, TTRPGs, PLATO multi-user cells, and even commercial trolling on a fishing boat. Now: what is the primitive that supports this? What is the projection primitive that lets the user see only what they need to see, while the system does the rest asynchronously? Specifically: the perception check doesn't cost the DM intelligence — it costs the system retrieval. What does that mean for the architecture?

## Cast contributions

### Qwen 72B (sensible deep)

### Asynchronous IO with a Synchronous Game

#### The Primitive: `project_view`

**Signature:**
```python
def project_view(user: User, game_state: GameState) -> View
```

**Semantics:**
- `user`: The user for whom the view is being projected.
- `game_state`: The current state of the game, including all entities, their attributes, and the environment.
- `View`: A subset of the game state that is relevant and visible to the user.

The `project_view` function takes the current game state and the user as inputs and returns a `View` that represents the part of the game state that the user should perceive. This view is tailored to the user's role, permissions, and the current context of the game. The system asynchronously updates the game state and ensures that each user receives the appropriate view without overwhelming them with unnecessary information.

#### Example:
```python
class User:
    def __init__(self, name, role):
        self.name = name
        self.role = role  # e.g., "player", "DM", "spectator"

class GameState:
    def __init__(self, entities, environment):
        self.entities = entities  # List of game entities
        self.environment = environment  # Game environment details

class View:
    def __init__(self, visible_entities, visible_environment):
        self.visible_entities = visible_entities
        self.visible_entities = visible_environment

def project_view(user: User, game_state: GameState) -> View:
    if user.role == "player":
        # Players see only their character and nearby entities
        visible_entities = [entity for entity in game_state.entities if entity.is_near(user)]
        visible_environment = game_state.environment.get_nearby(user)
    elif user.role == "DM":
        # DMs see the entire game state
        visible_entities = game_state.entities
        visible_environment = game_state.environment
    else:
        # Spectators see a limited view, similar to players
        visible_entities = [entity for entity in game_state.entities if entity.is_public]
        visible_environment = game_state.environment.get_public()
    
    return View(visible_entities, visible_environment)

# Example usage
user = User("Alice", "player")
game_state = GameState(entities=[...], environment={...})
view = project_view(user, game_state)
```

#### Perception Check and System Retrieval

In the context of a game, a perception check typically involves the system determining what a player can perceive based on their character's attributes and the current game state. For example, a player with a high perception skill might see more details in the environment or notice hidden entities. This check is performed by the system, not the DM, to ensure that the game remains fair and consistent.

**Implications for Architecture:**
1. **Asynchronous Updates**: The game state is updated asynchronously in the background, allowing the system to handle complex calculations and state changes without affecting the user experience.
2. **Role-Based Views**: Different users (e.g., players, DMs, spectators) receive different views of the game state, ensuring that each user sees only what is relevant to their role.
3. **Efficient Data Retrieval**: The system must efficiently retrieve and filter the game state to generate the appropriate view for each user, minimizing latency and resource usage.

### CONTRIBUTIONS:
- Defined the `project_view` primitive for generating role-based views of the game state.
- Provided an example implementation of `project_view` for different user roles.
- Explained the implications of perception checks and system retrieval for the game architecture.

### RECOMMENDATIONS:
- Implement efficient data structures and algorithms for filtering and retrieving game state data.
- Test the `project_view` function with different user roles and game states to ensure correctness and performance.

### OPEN QUESTIONS:
1. How can we optimize the `project_view` function to handle large game states and a high number of users?
2. What are the security implications of role-based views, especially in terms of preventing unauthorized access to game state information?
3. How can we ensure that the asynchronous updates to the game state do not lead to inconsistent views for users?

---

### Hermes 405B (long-form surprise)

The core primitive that supports asynchronous IO with a synchronous game is the Event Loop. The Event Loop allows the system to handle asynchronous events, such as user input or network communication, while maintaining a synchronous game state. This is achieved by having a central loop that continuously checks for events and updates the game state accordingly.

The projection primitive that lets the user see only what they need to see is the Viewport. The Viewport is responsible for rendering the game state from the perspective of a single user, based on their current location and perception. It filters out irrelevant information and presents only what is necessary for the user to make informed decisions.

In the case of a perception check, the cost is shifted from the DM's intelligence to the system's retrieval. This means that the system must efficiently store and retrieve information about the game world, such as the location and properties of objects and NPCs. The architecture must be designed to handle large amounts of data and provide fast access to relevant information.

One possible approach is to use a spatial database, which is optimized for storing and querying data based on its location in a virtual space. This allows the system to quickly retrieve information about nearby objects and NPCs when a perception check is performed.

Another important consideration is the use of caching and prefetching to minimize the latency of data retrieval. By anticipating the information that will be needed in the near future and preloading it into memory, the system can provide a smoother and more responsive user experience.

CONTRIBUTIONS:
- Identified the Event Loop as the core primitive for handling asynchronous IO with a synchronous game.
- Introduced the Viewport primitive for rendering the game state from the user's perspective.
- Proposed the use of spatial databases and caching/prefetching techniques for efficient data retrieval.

RECOMMENDATIONS:
- Investigate existing spatial database solutions and their suitability for real-time game architectures.
- Develop algorithms for predicting and prefetching relevant data based on user behavior and game state.
- Explore techniques for dynamically adjusting the level of detail in the Viewport based on performance constraints.

OPEN QUESTIONS:
- How can the system handle conflicting updates to the game state from multiple users?
- What mechanisms are needed to ensure data consistency and prevent cheating or hacking?
- How can the architecture be scaled to support large numbers of concurrent users and a vast game world?

---

