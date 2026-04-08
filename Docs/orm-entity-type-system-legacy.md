# 🏗️ ORM Metadata Architecture: The `TEntityType<T>` System

## 🎯 Vision
Transform the Dext ORM from a runtime reflection-based system into a **Static Type Model** system. This enables:
1.  **Extreme Performance**: Pre-cached accessors and converters (no runtime parsing).
2.  **Type Safety**: Compile-time checking for queries (e.g., `Where(User.Age > 18)`).
3.  **Developer Experience**: Rich metadata for IDE experts, validation, and automated UI generation.

---

## 📐 Core Architecture

### 1. The Evolution: From "Strings" to "Types"

We are moving from a "flexible but unsafe" approach to a "strict and fast" model, inspired by **C# Entity Framework** and **Spring4D**.

| Feature | Current (`UserEntity.Name`) | New (`TUserType.Name`) |
| :--- | :--- | :--- |
| **Syntax** | `Where(Prop('Age') > 18)` | `Where(TUserType.Age > 18)` |
| **Type Safety** | ❌ None (`Age > 'text'` compiles) | ✅ **Strict** (`Age > 'text'` Error) |
| **Performance** | ⚠️ Generic RTTI lookup | 🚀 **Zero-Lookup** (Cached PTypeInfo) |
| **Boilerplate** | ⚠️ Manual `class constructor` | ✨ **Auto-Generated** (Experts/CLI) |

### 2. The Hybrid Model: Class for Metadata, Record for Syntax

To support natural syntax like `Where(User.Age > 18)` while keeping deep metadata capabilities, we separate concerns:
*   **`TPropertyMeta` (Class)**: Holds heavy RTTI data (PropInfo, TypeInfo, Converters).
*   **`TProp<T>` (Record)**: A lightweight wrapper with Operator Overloading for type-safe expressions.

```pascal
type
  // The Heavy Metadata (Class)
  TPropertyMeta = class
  public
    Name: string;
    PropInfo: PPropInfo;
    PropTypeInfo: PTypeInfo;
    Converter: IValueConverter;
    // ... Accessors ...
  end;

  // The Syntax Wrapper (Record)
  TProp<T> = record
  private
    FMeta: TPropertyMeta;
  public
    // Operator Overloading (Typed!)
    // Enables: Where(User.Age > 18)
    class operator GreaterThan(const Left: TProp<T>; Right: T): TExpression;
    class operator Equal(const Left: TProp<T>; Right: T): TExpression;
    
    // Implicit Conversion to untyped TPropExpression (Legacy Compatibility)
    class operator Implicit(const Value: TProp<T>): TPropExpression;
    
    // Access underlying metadata
    property Meta: TPropertyMeta read FMeta;
  end;
```

### 3. `TEntityType<T>`: The Static Registry

```pascal
type
  TUserType = class(TEntityType<TUser>)
  public
    // Entity Metadata
    class var EntityTypeInfo: PTypeInfo;
    
    // Static Typed Properties (Records!)
    class var Id: TProp<Integer>;
    class var Name: TProp<string>;
    class var Role: TProp<TRoleType>;
    
    // Initialization
    class constructor Create; // Auto-generated
  end;
```
    class var Email: TPropertyMeta<TUser, string>;
    class var Role: TPropertyMeta<TUser, TRoleType>;
    
    // Validations & Contracts
    class function Validate(Instance: TUser): TValidationResult;
  end;
```

---

## 🛡️ Features & Capabilities

### 1. Type-Safe Query Expressions
No more magic strings. Queries become checked by the compiler.

```pascal
// Compilation Error if you try to compare String > Integer
// Error: Incompatible types: 'string' and 'Integer'
Query.Where(TUserType.Name > 10); 

// Correct Usage
Query.Where(TUserType.Age > 18)
     .And(TUserType.Role.Eq(TRole.Admin));
```

### 2. High-Performance Hydration
Hydration bypasses RTTI lookups entirely by iterating the metadata-cached accessors.

```pascal
// Inside TEntityType<T>.Hydrate(Instance, ResultSet)
// Loop unrolling or direct array access possible
for var Prop in FProperties do
begin
  // Direct Virtual Method Call (Fast) -> Converter (Fast) -> Setter (Fast)
  Prop.LoadValue(Instance, ResultSet); 
end;
```

### 3. Metadata for UI & Views
The metadata can drive UI generation ("Scaffolding at Runtime").

```pascal
// Usage in a View/Component
EditField.Label := TUserType.Name.DisplayName; // "Full Name"
EditField.MaxLength := TUserType.Name.MaxLength; // 100
EditField.Required := TUserType.Name.IsRequired; // True
```

### 4. Code Generation Experts
To avoid writing the `TEntityType` boilerplate manually, we implement **Design-Time Experts**:
- **Right-Click -> Generate Entity Type**: Scans the class and generates the `TUserType` declaration in a `User.Meta.pas` unit.
- **Domain Aggregate Unit**: Option to generate a "Joker" unit (e.g., `Sales.Entities.pas`) that re-exports all entity types for a specific domain, simplifying imports.
- **On-Save Hook**: Automatically updates the metadata when the Entity class changes.

---

## 🛠️ Implementation Roadmap

### Phase 1: Core Metadata (`Sources\Data\TypeSystem`)
- [ ] Define generic `TPropertyMeta<T, TProp>`.
- [ ] Implement `TEntityType<T>` registry base.
- [ ] Implement `TModelBuilder` to fill metadata via RTTI (fallback).

### Phase 2: Expression Engine (`Sources\Data\Query`)
- [ ] Update `IPredicate` to accept `TPropertyMeta`.
- [ ] Implement operator overloads (`>`, `<`, `=`, `In`).

### Phase 3: Validation & Rules
- [ ] Add `ValidationAttributes` parsing strategy.
- [ ] Implement `IValidator<T>` interface in `TEntityType<T>`.

### Phase 4: Compatibility & Migration
- [ ] Refactor `Dext.Data.Entity` to use `TEntityType` if available, falling back to cached RTTI if not.
- [ ] Create CLI/Wizard tool for generating Metadata units.
