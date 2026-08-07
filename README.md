# Broom
Super fast simple cleanup module

### Add Test (100K objects)

| Cleanup Tool | Time Taken (s) | Broom Speedup
|--------------------|------------------------|--------------------|
| Janitor | .0280 | 1.98x
| Maid | .0294 | 2.08x
| Trove | .0310 | 2.19x
| **Broom** | **.0141** | 1x

### Cleanup Test (100K objects)

| Cleanup Tool | Time Taken (s) | Broom Speedup
|--------------------|------------------------|--------------------|
| Janitor | 5.015 | 1475x
| Maid | 2.665 | 783.82x
| Trove | .0148 | 4.35x
| **Broom** | **.0034** | 1x
