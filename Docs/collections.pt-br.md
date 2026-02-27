# 📦 Dext.Collections

O `Dext.Collections` é o motor de gerenciamento de dados em memória do **Dext Framework**. Diferente das coleções padrão do Delphi (`System.Generics.Collections`), as coleções do Dext foram projetadas para resolver os três grandes problemas do desenvolvimento moderno em Object Pascal: **Memory Leaks (Ownership)**, **Verbocidade (LINQ)** e **Performance de Compilação**.

## 🚀 Por que usar Dext.Collections?

1. **Segurança de Memória Automática (ARC-like)**: As coleções são baseadas em interfaces (`IList<T>`, `IDictionary<K,V>`). Você nunca mais precisará chamar `.Free` em uma lista enviada por um método.
2. **Gerenciamento de Dono (Ownership)**: Suporte nativo para `OwnsObjects`. Se você criar uma lista de objetos, ela sabe quando deve destruir os elementos e quando deve apenas manter a referência.
3. **API Funcional (LINQ)**: Métodos poderosos como `Where`, `Select`, `Any`, `All`, `First`, `OrderBy` integrados diretamente na interface.
4. **Integração com ORM**: O `Dext.Entity` utiliza estas coleções para retornar resultados de busca e gerenciar relacionamentos (HasMany), permitindo filtros em memória com a mesma sintaxe do banco de dados.

---

## 🛠️ Guia de Uso

### 1. Declaração e Criação

Sempre prefira usar as **Interfaces** para garantir o gerenciamento automático de memória.

```delphi
uses
  Dext.Collections;

var
  Users: IList<TUser>;
  Settings: IDictionary<string, string>;
begin
  // Lista de Objetos (Destrói os objetos automaticamente por padrão)
  Users := TCollections.CreateObjectList<TUser>; 
  
  // Lista Simples (Integers, Records, Strings)
  var Numbers := TCollections.CreateList<Integer>;

  // Dicionários
  Settings := TCollections.CreateDictionary<string, string>;
end; // <-- Users e Settings são liberados aqui automaticamente
```

### 2. Gerenciamento de Ownership (Dono)

O conceito de "Ownership" é crucial no Delphi. No Dext, é suave:

- **Lista de Objetos**: Por padrão, o Dext assume que a lista **é dona** dos objetos.
- **Transferência de Posse**: Se você quer que a lista apenas referencie objetos externos, use:

```delphi
// Esta lista NÃO vai liberar os objetos no .Clear ou ao ser destruída
Users := TCollections.CreateList<TUser>(False); 
```

### 3. LINQ e Operações Funcionais

Escreva código mais limpo e expressivo.

```delphi
// Filtragem avançada
var ActiveAdmins := Users
  .Where(function(U: TUser): Boolean
    begin
      Result := U.IsActive and (U.Role = 'Admin');
    end)
  .OrderBy(function(U: TUser): string
    begin
      Result := U.Name;
    end)
  .ToList;

// Verificações rápidas
if Users.Any(function(U: TUser): Boolean begin Result := U.Age > 18 end) then
  Writeln('Existem adultos na lista');

// Transformação (Projeção)
var Names: IList<string> := Users.Select<string>(
  function(U: TUser): string begin Result := U.Name end).ToList;
```

### 4. Suporte a Expressões (O Diferencial ✨)

Graças ao `Dext.Specifications`, você pode filtrar listas usando operadores lógicos sem escrever funções anônimas verbosas.

```delphi
uses 
  Dext.Collections, 
  Dext.Specifications.Expression;

// Filtro direto por propriedade (usa RTTI interna otimizada)
var SpecificUsers := Users.Where(Prop('Status') = 'Active');
```

---

## 🏗️ Arquitetura Interna

### TSmartList<T>

A implementação padrão de `IList<T>`. Ela herda de `TInterfacedObject`, permitindo o ciclo de vida gerenciado por interface. Internamente, ela encapsula a `TList<T>` nativa para manter a performance de acesso direto à memória, mas adiciona as camadas de abstração funcional.

### TSmartDictionary<K, V>

Implementação de `IDictionary<K,V>`. Resolve o problema de iterar sobre dicionários e gerenciar a vida útil de chaves e valores complexos.

---

## 📊 Tabela Comparativa

| Feature | System.Generics.Collections | Dext.Collections |
| :--- | :---: | :---: |
| **Lifecycle** | Manual (`.Free`) | Automático (Interface) |
| **LINQ** | Limitado / TEnumerable | Completo (`IList<T>`) |
| **Ownership** | Configurado no Constructor | Nativo e Inteligente |
| **Sintaxe Fluente**| Não | Sim |
| **Uso em Parâmetros**| Risco de Leak | 100% Seguro |

---

## 📝 Boas Práticas

1. **Não misture**: Se começou a usar `IList<T>`, evite converter para `TList<T>` manuais para não perder o rastreamento de referência.
2. **Filtros**: Use `.Where().ToList` se precisar de uma cópia física dos dados, ou apenas itere sobre `.Where()` para economia de memória.
3. **Ownership**: Ao receber uma lista de um serviço (como um Repositório), assuma que você é o dono da lista, mas a lista gerencia os objetos internos.

---

## 🚀 Próximos Passos

Estamos trabalhando em uma otimização adicional de **Lazy Evaluation** e redução de símbolos genéricos para diminuir ainda mais o tempo de compilação em projetos gigantes, mantendo a performance de execução no topo.
