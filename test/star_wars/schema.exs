# Copyright (c) 2015, Facebook, Inc.
# All rights reserved.
#
#  This source code is licensed under the BSD-style license found in the
#  LICENSE file in the root directory of this source tree. An additional grant
#  of patent rights can be found in the PATENTS file in the same directory.

defmodule StarWars.Schema do
  @moduledoc """
   This is designed to be an end-to-end test, demonstrating
   the full GraphQL stack.

   We will create a GraphQL schema that describes the major
   characters in the original Star Wars trilogy.

   NOTE: This may contain spoilers for the original Star
   Wars trilogy.


   Using our shorthand to describe type systems, the type system for our
   Star Wars example is:

       enum Episode { NEWHOPE, EMPIRE, JEDI }

       interface Character {
         id: String!
         name: String
         friends: [Character]
         appearsIn: [Episode]
       }

       type Human : Character {
         id: String!
         name: String
         friends: [Character]
         appearsIn: [Episode]
         homePlanet: String
       }

       type Droid : Character {
         id: String!
         name: String
         friends: [Character]
         appearsIn: [Episode]
         primaryFunction: String
       }

       type Query {
         hero(episode: Episode): Character
         human(id: String!): Human
         droid(id: String!): Droid
       }

   We begin by setting up our schema.

  """

  alias ExGraphQL.Type
  alias StarWars.Data


  # Uses the `queryType` defined below
  @doc "The schema"
  def schema do
    %Type.Schema{query: queryType}
  end


  # The original trilogy consists of three movies.
  #
  # This implements the following type system shorthand:
  #
  #     enum Episode { NEWHOPE, EMPIRE, JEDI }
  #
  defp episodeEnum do
    %Type.Enum{
      name: 'Episode',
      description: 'One of the films in the Star Wars Trilogy',
      values: %{
        NEWHOPE: %{
          value: 4,
          description: 'Released in 1977.'},
        EMPIRE: %{
          value: 5,
          description: 'Released in 1980.'},
        JEDI: %{
          value: 6,
          description: 'Released in 1983.'}}}
  end

  # Characters in the Star Wars trilogy are either humans or droids.
  #
  # This implements the following type system shorthand:
  #
  #     interface Character {
  #       id: String!
  #       name: String
  #       friends: [Character]
  #       appearsIn: [Episode]
  #     }
  #
  defp characterInterface do
    %Type.InterfaceType{
      name: 'Character',
      description: 'A character in the Star Wars Trilogy',
      fields: fn -> %{
        id: %{
          type: %Type.NonNull{of_type: Type.String},
          description: 'The id of the character.'},
        name: %{
          type: Type.String,
          description: 'The name of the character.'},
        friends: %{
          type: %Type.List{of_type: characterInterface},
          description: 'The friends of the character, or an empty list if they have none.'},
        appearsIn: %{
          type: %Type.List{of_type: episodeEnum},
          description: 'Which movies they appear in.'}}
      end,
      resolveType: fn (character) ->
        if Data.getHuman(character.id) do
          humanType
        else
          droidType
        end
      end}
  end

  # We define our human type, which implements the character interface.
  #
  # This implements the following type system shorthand:
  #
  #     type Human : Character {
  #       id: String!
  #       name: String
  #       friends: [Character]
  #       appearsIn: [Episode]
  #     }
  #
  defp humanType do
    %Type.ObjectType{
      name: 'Human',
      description: 'A humanoid creature in the Star Wars universe.',
      fields: fn -> %{
        id: %{
          type: %Type.NonNull{of_type: Type.String},
          description: 'The id of the human.'},
        name: %{
          type: Type.String,
          description: 'The name of the human.'},
        friends: %{
          type: %Type.List{of_type: characterInterface},
          description: 'The friends of the human, or an empty list if they have none.',
          resolve: &Data.getFriends/1},
        appearsIn: %{
          type: %Type.List{of_type: episodeEnum},
          description: 'Which movies they appear in.'},
        homePlanet: %{
          type: Type.String,
          description: 'The home planet of the human, or null if unknown.'}}
      end,
      interfaces: [characterInterface]}
  end

  # The other type of character in Star Wars is a droid.
  #
  # This implements the following type system shorthand:
  #
  #     type Droid : Character {
  #       id: String!
  #       name: String
  #       friends: [Character]
  #       appearsIn: [Episode]
  #       primaryFunction: String
  #     }
  #
  defp droidType do
    %Type.ObjectType{
      name:  'Droid',
      description: 'A mechanical creature in the Star Wars universe.',
      fields: fn -> %{
        id: %{
          type: %Type.NonNull{of_type: Type.String},
          description: 'The id of the droid.'},
        name: %{
          type: Type.String,
          description: 'The name of the droid.'},
        friends: %{
          type: %Type.List{of_type: characterInterface},
          description: 'The friends of the droid, or an empty list if they have none.',
          resolve: &Data.getFriends/1},
        appearsIn: %{
          type: %Type.List{of_type: episodeEnum},
          description: 'Which movies they appear in.'},
        primaryFunction: %{
          type: Type.String,
          description: 'The primary function of the droid.'}}
      end,
      interfaces: [characterInterface]}
  end

  # This is the type that will be the root of our query, and the
  # entry point into our schema. It gives us the ability to fetch
  # objects by their IDs, as well as to fetch the undisputed hero
  # of the Star Wars trilogy, R2-D2, directly.
  #
  # This implements the following type system shorthand:
  #
  #     type Query {
  #       hero(episode: Episode): Character
  #       human(id: String!): Human
  #       droid(id: String!): Droid
  #     }
  defp queryType do
    %Type.ObjectType{
      name: 'Query',
      fields: fn -> %{
        hero: %{
          type: characterInterface,
          args: %{
            episode: %{
              description: 'If omitted, returns the hero of the whole saga. If provided, returns the hero of that particular episode.',
              type: episodeEnum}},
                resolve: fn (_root, %{episode: episode}) -> StarWarsDat.getHero(episode) end},
        human: %{
          type: humanType,
          args: %{
            id: %{
              description: 'id of the human',
              type: %Type.NonNull{of_type: Type.String}}},
                 resolve: fn (_root, %{id: id}) -> Data.getHuman(id) end},
        droid: %{
          type: droidType,
          args: %{
            id: %{
              description: 'id of the droid',
              type: %Type.NonNull{of_type: Type.String}}},
                 resolve: fn (_root, %{id: id}) ->
                   Data.getDroid(id)
                 end}}
    end}
  end

end