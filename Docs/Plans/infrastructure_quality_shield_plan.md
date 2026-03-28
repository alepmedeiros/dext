# Infrastructure Quality Shield Plan - Dext Framework

## 1. Objective
Ensure absolute stability of the Dext Framework core by implementing a "Quality Shield" around the foundational units. This plan focuses on preventing regressions in critical data handling and mapping layers, especially concerning the hybrid Smart Properties (`Prop<T>`) and Reflection cache.

## 2. Critical Units for Shielding
| Unit | Responsibility | Risk Level |
| :--- | :--- | :--- |
| `Dext.Core.SmartTypes` | Hybrid Record Operators (Query vs Runtime) | **CRITICAL** |
| `Dext.Core.Reflection` | Type Metadata Cache & Property Unwrapping | **CRITICAL** |
| `Dext.Entity.Mapping` | Attributes, Fluent API, and Prototype Injection | HIGH |
| `Dext.Json` | Core Serialization Patterns | HIGH |
| `Dext.Collections` | List/Dictionary foundational stability | MEDIUM |

## 3. Test Coverage Strategy

### A. Combinatorial Smart Property Tests
**Goal:** Verify all 9 standard types against all core operations.
- **Types:** `StringType`, `IntType`, `Int64Type`, `BoolType`, `FloatType`, `CurrencyType`, `DateTimeType`, `DateType`, `TimeType`.
- **Operations to Validate:**
  - Implicit/Explicit Casting (to/from raw types).
  - Operator Overloading (Equal, NotEqual, Arithmetic for numbers).
  - DataSet Interop (Auto-detection of fields in `TEntityDataSet`).
  - Json Interop (Serialization/Deserialization without data loss).

### B. Reflection Cache & Metadata Robustness
**Goal:** Validate that `TReflection` never loses property context.
- **Scenarios:**
  - Generic Record detection (handling `Prop<T>` in obfuscated or complex RTTI scenarios).
  - Value Unwrapping/Wrapping (Ensuring `TValue` correctly extracts `FValue` from a `Prop<T>`).
  - Thread-safety of `TTypeMetadata` cache.

### C. Advanced Mapping & Fluent API
**Goal:** Ensure 100% collision-free mapping between Class and Database.
- **Scenarios:**
  - Attribute vs Fluent precedence (Fluent must always win).
  - Primary Key combos (Single, Composite, AutoInc).
  - Nullable SmartProps in Mapping.

## 4. Status of Existing Tests
Based on the current repository analysis, the following tests already satisfy parts of the infrastructure:

- [x] **Collections Stability:** `Tests/Collections/TestCollections.dpr` covers core list/dict logic.
- [x] **Basic DataSet:** `Tests/Entity/DataSet/Dext.EntityDataSet.Tests.dpr` covers basic CRUD and navigation.
- [x] **Entity Logic:** `Tests/Entity/UnitTests/Dext.Entity.UnitTests.dpr` covers SQL generation and base ORM behavior.
- [x] **DTO Mapping:** `Tests/Core/TestMapper.dpr` covers value copy between classes.
- [ ] **Infrastructure Shield (GAP):** Comprehensive "Combination Matrix" tests for SmartProps are missing.

## 4. Implementation Priorities (Action Items)
1. **[NEW]** `Tests/Core/Dext.Core.SmartTypes.Combinatorial.Tests.pas`: One test suite to rule all types.
2. **[NEW]** `Tests/Entity/Dext.Entity.Mapping.Advanced.Tests.pas`: Stress testing the Fluent API with complex edge cases.
3. **[REFACTOR]** Expand `TEntityDataSetTests` to include at least one entity composed entirely of SmartProperties.

---
*Created by Antigravity AI Consultant*
