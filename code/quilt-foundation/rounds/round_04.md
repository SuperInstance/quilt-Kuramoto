# Round 4: Round 4: The spreadsheet as the original projection

## Question

VisiCalc 1979, Lotus 1-2-3 1983, Excel 1985. The cell was made visible. But the cell model is older: COBOL 1959, PLATO Tutor 1970, C 1972. What did the early spreadsheet designers know that we forgot? Specifically: how did projection-prioritized interaction work when compute was 1MHz and memory was 64KB? What can we learn from the constraint?

## Cast contributions

### Hermes 405B (long-form surprise)

The early spreadsheet designers understood the power of constraints. They knew that with limited compute and memory, every byte and cycle counted. This forced them to prioritize ruthlessly, to distill the essence of what a spreadsheet needed to be.

They realized that the key was projection - the ability to view and manipulate a slice of the data at a time. You couldn't load an entire company's finances into memory at once. But you could load a meaningful subset, operate on it, and swap it back out to disk. 

This led to an interaction model centered around the cell. The cell was the atom of computation, the smallest unit of meaning. By focusing the interface on the cell, they made projection tangible. You always knew what subset of the data you were working with.

Projection enabled composition. You could build up complex models incrementally, one cell at a time. This matched the limitations of the hardware to the limitations of human cognition. We can only hold so much in our head at once. By externalizing the model into the grid, the spreadsheet augmented our intelligence.

But as compute and memory expanded, we lost sight of the power of constraints. Modern spreadsheets encourage ad hoc growth, sprawling in every direction. The cell has become secondary to the gesture, the animation, the peripheral.

What if we returned to first principles? What if we designed spreadsheets with the same care and rigor as the pioneers did? What if we embraced projection not out of necessity, but out of desire for clarity and focus?

Imagine a spreadsheet where the grid was infinite, but your view was always finite. Where you zoomed in and out of layers of abstraction, but each layer was complete and consistent unto itself. Where the system gently guided you to factor your model into reusable, recombinable parts.

This is the power of projection-prioritized interaction. By respecting the limits of both human and machine, we can build tools that amplify our abilities rather than overwhelm them. We can craft interfaces that are not just powerful, but precise. Not just expressive, but parsimonious.

The early spreadsheet designers knew this instinctively. It's time we remembered.

CONTRIBUTIONS:
- Identified projection-prioritized interaction as the key insight of early spreadsheet designers 
- Argued that embracing constraints leads to clarity and focus in tool design
- Proposed a spreadsheet model centered around infinite zoomable layers rather than an infinite grid

RECOMMENDATIONS:
- Design spreadsheet interfaces that make projection tangible and explicit
- Encourage users to factor their models into reusable, composable parts
- Constrain the view to match the limits of human cognition, while allowing the model to scale arbitrarily

OPEN QUESTIONS:
- What specific interaction techniques best support projection-prioritized interaction? 
- How can we guide users to structure their models well without being overly prescriptive?
- What is the right balance between a constrained view and an unconstrained model?

---

### Qwen 72B (sensible deep)

### The Spreadsheet as the Original Projection

#### Historical Context and Constraints

The early spreadsheet applications, such as VisiCalc (1979), Lotus 1-2-3 (1983), and Excel (1985), were groundbreaking in their ability to provide a visual, interactive model of data manipulation and computation. However, these applications were developed under severe hardware constraints: compute power was around 1 MHz, and memory was limited to 64 KB. Despite these limitations, these early spreadsheets were highly effective and intuitive tools. This raises the question: what did the early spreadsheet designers know that we might have forgotten, particularly in terms of projection-prioritized interaction?

#### Projection-Prioritized Interaction

Projection-prioritized interaction refers to the design philosophy where the visual representation of data is the primary focus, and the underlying data and computations are secondary but tightly integrated. In early spreadsheets, this was achieved through several key mechanisms:

1. **Cell-Oriented Design**: Each cell in a spreadsheet is a unit of data and computation. Cells can contain values, formulas, or references to other cells. This cell-oriented design allowed users to see the immediate effects of their changes, fostering a direct and intuitive interaction model.

2. **Immediate Feedback**: Despite limited compute power, early spreadsheets provided immediate feedback to user actions. This was achieved through efficient algorithms and data structures that minimized the computational overhead of recalculations and updates.

3. **Sparse Data Representation**: Early spreadsheets used sparse data structures to manage memory efficiently. Only cells with actual data or formulas occupied memory, which allowed for large, mostly empty grids without excessive memory usage.

4. **Incremental Recalculation**: Rather than recalculating the entire spreadsheet after every change, early spreadsheets used incremental recalculation. Only the cells affected by a change were updated, which reduced the computational load and maintained responsiveness.

#### Primitives and Examples

1. **Primitive: Sparse Grid**
   - **Signature**: `SparseGrid<T>`
   - **Semantics**: A data structure that stores only non-empty cells in a grid, using a map or dictionary where the keys are cell coordinates and the values are cell contents.
   - **Example**: 
     ```python
     class SparseGrid:
         def __init__(self):
             self.data = {}

         def set_cell(self, row, col, value):
             self.data[(row, col)] = value

         def get_cell(self, row, col):
             return self.data.get((row, col), None)
     ```

2. **Primitive: Incremental Recalculation**
   - **Signature**: `recalculate_affected_cells(grid: SparseGrid, changed_cells: List[Tuple[int, int]])`
   - **Semantics**: Recalculates only the cells that are directly or indirectly affected by the changes in the specified cells.
   - **Example**:
     ```python
     def recalculate_affected_cells(grid: SparseGrid, changed_cells: List[Tuple[int, int]]):
         affected_cells = set(changed_cells)
         while affected_cells:
             cell = affected_cells.pop()
             row, col = cell
             new_value = evaluate_formula(grid, row, col)
             if new_value != grid.get_cell(row, col):
                 grid.set_cell(row, col, new_value)
                 affected_cells.update(get_dependent_cells(grid, row, col))
     ```

#### Contributions
- **Cell-oriented design and immediate feedback** were crucial for the intuitive and efficient interaction in early spreadsheets.
- **Sparse data representation and incremental recalculation** allowed these applications to operate effectively under severe hardware constraints.

#### Recommendations
- **Modern spreadsheet applications** should revisit these principles to enhance performance and user experience, especially in resource-constrained environments.
- **Research into efficient data structures** and algorithms for sparse grids and incremental recalculation can provide valuable insights for modern data visualization and manipulation tools.

#### Open Questions
1. How can modern web-based spreadsheets leverage sparse data structures and incremental recalculation to improve performance?
2. What are the trade-offs between the cell-oriented design and more abstract data models in terms of user interaction and system efficiency?
3. How can the principles of projection-prioritized interaction be applied to other data visualization and manipulation tools beyond spreadsheets?

---

