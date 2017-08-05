require "test_helper"

class TypeAssignabilityTest < Minitest::Test
  T = Steep::Types
  Parser = Steep::Parser

  def parse_method(src)
    Parser.parse_method(src)
  end

  def parse_signature(src, &block)
    Parser.parse_signature(src).each(&block)
  end

  def test_any_any
    assignability = Steep::TypeAssignability.new
    assert assignability.test(src: T::Any.new, dest: T::Any.new)
  end

  def test_if1
    if1, if2 = Parser.parse_signature(<<-EOS)
interface _Foo
end

interface _Bar
end
    EOS

    assignability = Steep::TypeAssignability.new
    assignability.add_interface if1
    assignability.add_interface if2

    assert assignability.test(src: T::Name.interface(name: :_Foo), dest: T::Name.interface(name: :_Bar))
  end

  def test_if2
    if1, if2 = Parser.parse_signature(<<-EOS)
interface _Foo
  def foo: -> any
end

interface _Bar
  def foo: -> any
end
    EOS

    assignability = Steep::TypeAssignability.new
    assignability.add_interface if1
    assignability.add_interface if2

    assert assignability.test(src: T::Name.interface(name: :_Foo), dest: T::Name.interface(name: :_Bar))
  end

  def test_method1
    a = Steep::TypeAssignability.new

    parse_signature(<<-EOS).each do |interface|
interface _A
  def foo: -> any
end

interface _B
  def bar: -> any
end
    EOS
      a.add_interface interface
    end

    assert a.test_method(parse_method("(_A) -> any"), parse_method("(_A) -> any"), [])
    assert a.test_method(parse_method("(_A) -> any"), parse_method("(any) -> any"), [])
    assert a.test_method(parse_method("(any) -> any"), parse_method("(_A) -> any"), [])
    refute a.test_method(parse_method("() -> any"), parse_method("(_A) -> any"), [])
    refute a.test_method(parse_method("(_A) -> any"), parse_method("(_B) -> any"), [])

    assert a.test_method(parse_method("(_A, ?_B) -> any"), parse_method("(_A) -> any"), [])
    refute a.test_method(parse_method("(_A) -> any"), parse_method("(_A, ?_B) -> any"), [])

    refute a.test_method(parse_method("(_A, ?_A) -> any"), parse_method("(*_A) -> any"), [])
    refute a.test_method(parse_method("(_A, ?_A) -> any"), parse_method("(*_B) -> any"), [])

    assert a.test_method(parse_method("(*_A) -> any"), parse_method("(_A) -> any"), [])
    refute a.test_method(parse_method("(*_A) -> any"), parse_method("(_B) -> any"), [])

    assert a.test_method(parse_method("(name: _A) -> any"), parse_method("(name: _A) -> any"), [])
    refute a.test_method(parse_method("(name: _A, email: _B) -> any"), parse_method("(name: _A) -> any"), [])

    assert a.test_method(parse_method("(name: _A, ?email: _B) -> any"), parse_method("(name: _A) -> any"), [])
    refute a.test_method(parse_method("(name: _A) -> any"), parse_method("(name: _A, ?email: _B) -> any"), [])

    refute a.test_method(parse_method("(name: _A) -> any"), parse_method("(name: _B) -> any"), [])

    assert a.test_method(parse_method("(**_A) -> any"), parse_method("(name: _A) -> any"), [])
    assert a.test_method(parse_method("(**_A) -> any"), parse_method("(name: _A, **_A) -> any"), [])
    assert a.test_method(parse_method("(name: _B, **_A) -> any"), parse_method("(name: _B, **_A) -> any"), [])

    refute a.test_method(parse_method("(name: _A) -> any"), parse_method("(**_A) -> any"), [])
    refute a.test_method(parse_method("(email: _B, **B) -> any"), parse_method("(**_B) -> any"), [])
    refute a.test_method(parse_method("(**_B) -> any"), parse_method("(**_A) -> any"), [])
    refute a.test_method(parse_method("(name: _B, **_A) -> any"), parse_method("(name: _A, **_A) -> any"), [])
  end

  def test_method2
    a = Steep::TypeAssignability.new

    parse_signature(<<-EOS).each do |interface|
interface _S
end

interface _T
  def foo: -> any
end
    EOS
      a.add_interface interface
    end

    assert a.test(src: T::Name.interface(name: :_T), dest: T::Name.interface(name: :_S))

    assert a.test_method(parse_method("() -> _T"), parse_method("() -> _S"), [])
    refute a.test_method(parse_method("() -> _S"), parse_method("() -> _T"), [])

    assert a.test_method(parse_method("(_S) -> any"), parse_method("(_T) -> any"), [])
    refute a.test_method(parse_method("(_T) -> any"), parse_method("(_S) -> any"), [])
  end

  def test_recursively
    a = Steep::TypeAssignability.new

    parse_signature(<<-EOS).each do |interface|
interface _S
  def this: -> _S
end

interface _T
  def this: -> _T
  def foo: -> any
end
    EOS
      a.add_interface interface
    end

    assert a.test(src: T::Name.interface(name: :_T), dest: T::Name.interface(name: :_S))
    refute a.test(src: T::Name.interface(name: :_S), dest: T::Name.interface(name: :_T))
  end

  def test_union_intro
    a = Steep::TypeAssignability.new

    parse_signature(<<-EOS).each do |interface|
interface _X
  def x: () -> any
end

interface _Y
  def y: () -> any
end

interface _Z
  def z: () -> any
end
    EOS
      a.add_interface interface
    end

    assert a.test(dest: T::Union.new(types: [T::Name.interface(name: :_X),
                                             T::Name.interface(name: :_Y)]),
                  src: T::Name.interface(name: :_X))

    assert a.test(dest: T::Union.new(types: [T::Name.interface(name: :_X),
                                             T::Name.interface(name: :_Y),
                                             T::Name.interface(name: :_Z)]),
                  src: T::Union.new(types: [T::Name.interface(name: :_X),
                                            T::Name.interface(name: :_Y)]))

    refute a.test(dest: T::Union.new(types: [T::Name.interface(name: :_X),
                                             T::Name.interface(name: :_Y)]),
                  src: T::Name.interface(name: :_Z))
  end

  def test_union_elim
    a = Steep::TypeAssignability.new

    parse_signature(<<-EOS).each do |interface|
interface _X
  def x: () -> any
  def z: () -> any
end

interface _Y
  def y: () -> any
  def z: () -> any
end

interface _Z
  def z: () -> any
end
    EOS
      a.add_interface interface
    end

    assert a.test(dest: T::Name.interface(name: :_Z),
                  src: T::Union.new(types: [T::Name.interface(name: :_X),
                                            T::Name.interface(name: :_Y)]))

    refute a.test(dest: T::Name.interface(name: :_X),
                  src: T::Union.new(types: [T::Name.interface(name: :_Z),
                                            T::Name.interface(name: :_Y)]))
  end

  def test_union_method
    a = Steep::TypeAssignability.new

    parse_signature(<<-EOS).each do |interface|
interface _X
  def f: () -> any
       : (any) -> any
       : (any, any) -> any
end

interface _Y
  def f: () -> any
       : (_X) -> _X
end
    EOS
      a.add_interface interface
    end

    assert a.test(src: T::Name.interface(name: :_X),
                  dest: T::Name.interface(name: :_Y))

    refute a.test(src: T::Name.interface(name: :_Y),
                  dest: T::Name.interface(name: :_X))
  end
end
