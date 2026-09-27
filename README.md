# Broom
Super fast simple cleanup module

# Benchmarks

### Add Test (100K objects)

| Cleanup Tool | Time Taken (s) | Broom Speedup
|--------------------|------------------------|--------------------|
| Janitor | .0280 | 1.98x
| Maid | .0294 | 2.08x
| Trove | .0310 | 2.19x
| Scythe | .0334 | 2.36x
| **Broom** | **.0141** | 1x

### Cleanup Test (100K objects)

| Cleanup Tool | Time Taken (s) | Broom Speedup
|--------------------|------------------------|--------------------|
| Janitor | 5.015 | 1475x
| Maid | 2.665 | 783.82x
| Trove | .0148 | 4.35x
| Scythe | .0208 | 6.11x
| **Broom** | **.0034** | 1x
