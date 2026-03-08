## Example 1: Adding a function with tests

**Task:** Add a `clamp(value, min, max)` function to `src/utils.py`

**Plan:** Add one function to utils.py, write two tests (within range, out of range).

**Test first (`tests/test_utils.py`):**
```python
def test_clamp_within_range():
    assert clamp(5, 1, 10) == 5

def test_clamp_below_min():
    assert clamp(-1, 0, 10) == 0

def test_clamp_above_max():
    assert clamp(15, 0, 10) == 10
```

**Then implement (`src/utils.py`):**
```python
def clamp(value: int, min_val: int, max_val: int) -> int:
    return max(min_val, min(max_val, value))
```

**Summary:**
**Plan executed:** Added clamp() with three tests as planned
**Changed:** src/utils.py, tests/test_utils.py
**Tests:** 3 passing — within range, below min, above max
**Trade-offs:** Used stdlib max/min over if-else for brevity
**Concerns:** None
