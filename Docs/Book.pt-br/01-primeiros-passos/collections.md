# 📦 Coleções Genéricas

O Dext inclui uma biblioteca de coleções moderna, projetada para ser leve, segura quanto à memória e rica em recursos funcionais (inspirada no LINQ). Ela é a espinha dorsal do framework, utilizada pelos módulos de ORM, Injeção de Dependência e Web.

## Por que não usar apenas `TList<T>`?

As coleções padrão do Delphi (`System.Generics.Collections`) possuem duas grandes desvantagens em arquiteturas modernas:

1. **Gerenciamento Manual de Memória**: Você deve sempre lembrar de chamar `.Free`. Isso é propenso a erros quando listas são passadas entre serviços ou camadas.
2. **Verbosidade**: Listas padrão exigem loops manuais para operações simples como filtrar ou verificar existência.

## Principais Recursos

- **Baseado em Interfaces (`IList<T>`)**: Gerenciamento automático de ciclo de vida via contagem de referência.
- **Ownership Seguro**: Tratamento inteligente de objetos. Eles são destruídos apenas quando a lista é "dona" deles.
- **Motor LINQ**: Métodos integrados como `Where`, `Select`, `Any`, `First` e `OrderBy`.
- **Integração com ORM**: Filtre os resultados do banco de dados em memória usando os mesmos padrões de especificação.

---

## Primeiros Passos

### Criando Coleções

Sempre utilize coleções através de seus nomes de interface. Use a factory `TCollections` para criar instâncias.

```pascal
uses
  Dext.Collections;

var
  Users: IList<TUser>;
begin
  // Cria uma lista que É DONA dos objetos (vai liberá-los automaticamente)
  Users := TCollections.CreateObjectList<TUser>;

  // Cria uma lista de tipos básicos (não requer lógica de ownership)
  var Numbers := TCollections.CreateList<Integer>;
end; // Tanto Users quanto Numbers são liberados com segurança aqui.
```

### Operações Básicas

```pascal
Users.Add(User1);
Users.AddRange([User2, User3]);

Writeln('Total: ', Users.Count);
Writeln('Primeiro Usuário: ', Users[0].Name);

Users.Remove(User1);
Users.Clear; // Libera objetos se OwnsObjects for True
```

---

## <a name="ownership"></a> Ownership & Segurança de Memória

A segurança de memória é um cidadão de primeira classe no Dext.

### Listas de Objetos

Quando você usa `TCollections.CreateObjectList<T>`, a lista assume a responsabilidade pelos objetos que você adiciona a ela.

- Quando um objeto é removido, ele é destruído.
- Quando a lista (interface) sai de escopo, todos os objetos restantes são destruídos.

### Listas de Referência

Se você quer manter uma lista de objetos, mas **não** destruí-los (porque eles pertencem a outra parte da aplicação), use `CreateList<T>(False)`:

```pascal
// False significa OwnsObjects = False
var RefList := TCollections.CreateList<TUser>(False);
```

---

## LINQ & Lógica Funcional

As Coleções Dext trazem o poder da programação funcional para o Delphi.

### Filtragem e Busca

```pascal
// Encontrar todos os admins ativos
var Admins := Users.Where(function(U: TUser): Boolean
  begin
    Result := U.IsActive and (U.Role = 'Admin');
  end).ToList;

// Verificar se existe algum usuário de London
if Users.Any(function(U: TUser): Boolean begin Result := U.City = 'London' end) then
  Writeln('Londoners encontrados!');

// Obter o primeiro match ou nil
var FirstVip := Users.FirstOrDefault(function(U: TUser): Boolean begin Result := U.IsVip end);
```

### Projeções (Transformação)

```pascal
// Obter uma lista apenas dos nomes (lista de strings)
var Names := Users.Select<string>(function(U: TUser): string
  begin
    Result := U.Name;
  end).ToList;
```

---

## Dica de Performance

Métodos como `.Where()` e `.Select()` retornam iteradores "lazy" por padrão. Eles não copiam a lista inteira imediatamente. Se você precisa apenas percorrer o resultado, não chame `.ToList`. Use `.ToList` apenas quando precisar armazenar o resultado ou retorná-lo de um método.

```pascal
// Eficiente: Nenhuma cópia é feita
for var Admin in Users.Where(IsAdmin) do
  Process(Admin);

// Necessário: O resultado será armazenado/retornado
Result := Users.Where(IsAdmin).ToList;
```
