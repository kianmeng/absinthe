defmodule Absinthe.Type.Object do
  alias Absinthe.Utils

  @moduledoc """
  Represents a non-leaf node in a GraphQL tree of information.

  Objects represent a list of named fields, each of which yield a value of a
  specific type. Object values are serialized as unordered maps, where the
  queried field names (or aliases) are the keys and the result of evaluating the
  field is the value.

  Also see `Absinthe.Type.Scalar`.

  ## Examples

  Given a type defined as the following (see `Absinthe.Type.Definitions`):

  ```
  @absinthe :type
  def person do
    %Absinthe.Type.Object{
      fields: fields(
        name: [type: :string],
        age: [type: :integer],
        best_friend: [type: :person],
        pets: [type: list_of(:pet)]
      )
    }
  end
  ```

  The "Person" type (referred inside Absinthe as `:person`) is an object, with
  fields that use `Absinthe.Type.Scalar` types (namely `:name` and `:age`), and
  other `Absinthe.Type.Object` types (`:best_friend` and `:pets`, assuming
  `:pet` is an object).

  Given we have a query that supports getting a person by name
  (see `Absinthe.Schema`), and a query document like the following:

  ```
  {
    person(name: "Joe") {
      name
      best_friend {
        name
        age
      }
      pets {
        breed
      }
    }
  }
  ```

  We could get a result like this:

  ```
  %{
    data: %{
      "person" => %{
        "best_friend" => %{
          "name" => "Jill",
          "age" => 29
        },
        "pets" => [
          %{"breed" => "Wyvern"},
          %{"breed" => "Royal Griffon"}
        ]
      }
    }
  }
  ```
  """

  alias Absinthe.Type
  use Absinthe.Introspection.Kind

  @typedoc """
  A defined object type.

  Note new object types (with the exception of the root-level `query`, `mutation`, and `subscription`)
  should be defined using `@absinthe :type` from `Absinthe.Type.Definitions`.

  * `:name` - The name of the object type. Should be a TitleCased `binary`. Set automatically when using `@absinthe :type` from `Absinthe.Type.Definitions`.
  * `:description` - A nice description for introspection.
  * `:fields` - A map of `Absinthe.Type.Field` structs. See `Absinthe.Type.Definitions.fields/1` and
  * `:args` - A map of `Absinthe.Type.Argument` structs. See `Absinthe.Type.Definitions.args/1`.
  * `:parse` - A function used to convert the raw, incoming form of a scalar to the canonical internal format.
  * `:interfaces` - A list of interfaces that this type guarantees to implement. See `Absinthe.Type.Interface`.
  * `:is_type_of` - A function used to identify whether a resolved object belongs to this defined type. For use with `:interfaces` entry and `Absinthe.Type.Interface`.

  The `:reference` key is for internal use.
  """
  @type t :: %{name: binary, description: binary, fields: map, interfaces: [Absinthe.Type.Interface.t], is_type_of: ((any) -> boolean), reference: Type.Reference.t}
  defstruct name: nil, description: nil, fields: nil, interfaces: [], is_type_of: nil, reference: nil

  def build([{identifier, name}], attrs) do
    fields = fields_ast(attrs[:fields])
    quote do
      def __absinthe_type__(unquote(name)) do
        __absinthe_type__(unquote(identifier))
      end
      def __absinthe_type__(unquote(identifier)) do
        %unquote(__MODULE__){
          name: unquote(name),
          interfaces: unquote(attrs[:interfaces] || []),
          fields: unquote_splicing(fields),
          is_type_of: unquote(attrs[:is_type_of]),
          description: @doc
        }
      end
    end
  end
  def build(identifier, attrs) do
    build([{identifier, Utils.camelize_lower(Atom.to_string(identifier))}], attrs)
  end

  defp fields_ast(fields) do
    ast = for {field_name, field_attrs} <- fields do
      name = field_name |> Atom.to_string |> Utils.camelize_lower
      field_data = [name: name] ++ field_attrs
      field_ast = quote do
        %Absinthe.Type.Field{
          unquote_splicing(field_data)
        }
      end
      {field_name, field_ast}
    end

    quote do: %{unquote_splicing(ast)}
  end

  @doc false
  @spec field(t, atom) :: Absinthe.Type.Field.t
  def field(%{fields: fields}, identifier) do
    fields
    |> Map.get(identifier)
  end

  defimpl Absinthe.Traversal.Node do
    def children(node, _traversal) do
      Map.values(node.fields) ++ node.interfaces
    end
  end

end
