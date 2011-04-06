require "helper"

class TestMetadata < Test::Unit::TestCase
  def test_metadata_build_uses_row_containers_for_resource
    doc = Nokogiri.parse(METADATA_RESOURCE)

    containers = Rets::Metadata.build(doc)

    assert_equal 1, containers.size

    resource_container = containers.first

    assert_instance_of Rets::Metadata::ResourceContainer, resource_container

    assert_equal 13, resource_container.resources.size

    resource = resource_container.resources.first

    assert_equal "ActiveAgent", resource["StandardName"]
  end

  def test_metadata_build_uses_system_container_for_system
    doc = Nokogiri.parse(METADATA_SYSTEM)

    containers = Rets::Metadata.build(doc)

    assert_equal 1, containers.size

    assert_instance_of Rets::Metadata::SystemContainer, containers.first
  end

  def test_metadata_build_uses_base_container_for_unknown_metadata_types
    doc = Nokogiri.parse(METADATA_UNKNOWN)

    containers = Rets::Metadata.build(doc)

    assert_equal 1, containers.size

    assert_instance_of Rets::Metadata::Container, containers.first
  end

  def test_metadata_uses
    #TODO
  end

  def test_resource_initialize
    fragment = { "ResourceID" => 'r' }
    resource = Rets::Metadata::Resource.new(fragment)
    assert_equal('r', resource.id)
    assert_equal([], resource.rets_classes)
  end

  def test_resource_build_lookup_tree
    metadata = stub(:metadata)
    resource = stub(:resource)

    Rets::Metadata::Resource.expects(:find_lookup_containers).
      with(metadata, resource).
      returns([stub(:lookups => [{"LookupName" => "Foo"}])])

    Rets::Metadata::Resource.expects(:find_lookup_type_containers).
      with(metadata, resource, "Foo").
      returns([stub(:lookup_types => [{"Value" => "111", "LongValue" => "Bar"}])])

    tree = Rets::Metadata::Resource.build_lookup_tree(resource, metadata)

    assert_equal ["Foo"], tree.keys
    assert_equal 1, tree["Foo"].size

    lookup_type = tree["Foo"].first

    assert_equal "111", lookup_type.value
    assert_equal "Bar", lookup_type.long_value
  end

  def test_resource_build_classes
    resource = stub(:resource)
    metadata = stub(:metadata)
    rets_class = stub(:rets_class)
    rets_class_fragment = stub(:rets_class_fragment)

    Rets::Metadata::RetsClass.expects(:build).with(rets_class_fragment, resource, metadata).returns(rets_class)
    Rets::Metadata::Resource.expects(:find_rets_classes).with(metadata, resource).returns([rets_class_fragment])
    classes = Rets::Metadata::Resource.build_classes(resource, metadata)
    assert([rets_class], classes)
  end

  def test_resource_build
    fragment = { "ResourceID" => "test" }
    lookup_types = stub(:lookup_types)
    classes = stub(:classes)
    metadata = stub(:metadata)
    Rets::Metadata::Resource.stubs(:build_lookup_tree => lookup_types)
    Rets::Metadata::Resource.stubs(:build_classes => classes)
    resource = Rets::Metadata::Resource.build(fragment, metadata)
    assert_equal(lookup_types, resource.lookup_types)
    assert_equal(classes, resource.rets_classes)
  end

  def test_resource_find_lookup_containers
    resource = stub(:id => "id")
    metadata = { :lookup => [stub(:resource => "id"), stub(:resource => "id"), stub(:resource => "a")] }
    lookup_containers = Rets::Metadata::Resource.find_lookup_containers(metadata, resource)
    assert_equal(2, lookup_containers.size)
    assert_equal(["id", "id"], lookup_containers.map(&:resource))
  end

  def test_resource_find_lookup_type_containers
    resource = stub(:id => "id")
    metadata = { :lookup_type => [stub(:resource => "id", :lookup => "look"),
                                  stub(:resource => "id", :lookup => "look"),
                                  stub(:resource => "id", :lookup => "not_look"),
                                  stub(:resource => "a",  :lookup => "look"),
                                  stub(:resource => "a",  :lookup => "not_look")
                                 ]}
    lookup_type_containers = Rets::Metadata::Resource.find_lookup_type_containers(metadata, resource, "look")
    assert_equal(2, lookup_type_containers.size)
    assert_equal(["id", "id"], lookup_type_containers.map(&:resource))
  end

  def test_resource_find_rets_classes
    resource = stub(:id => "id")
    rets_classes = stub(:rets_classes)
    metadata = { :class => [stub(:resource => "id", :classes => rets_classes),
                            stub(:resource => "id", :classes => rets_classes),
                            stub(:resource => "a")]}
    assert_equal(rets_classes, Rets::Metadata::Resource.find_rets_classes(metadata, resource))
  end

  def test_resource_find_rets_class
    resource = Rets::Metadata::Resource.new({})
    value = mock(:name => "test")
    resource.expects(:rets_classes).returns([value])
    assert_equal(value, resource.find_rets_class("test"))
  end

  def test_lookup_type_initialize
    fragment = { "Value" => 'a',
                 "ShortValue" => 'b',
                 "LongValue" => 'c'
               }

    lookup_type = Rets::Metadata::LookupType.new(fragment)
    assert_equal('a', lookup_type.value)
    assert_equal('b', lookup_type.short_value)
    assert_equal('c', lookup_type.long_value)
  end

  def test_rets_class_find_table
    rets_class = Rets::Metadata::RetsClass.new({}, "resource")
    value = mock(:name => "test")
    rets_class.expects(:tables).returns([value])
    assert_equal(value, rets_class.find_table("test"))
  end

  def test_rets_class_find_table_container
    resource = mock(:id => "a")
    rets_class = mock(:name => "b")
    table = mock(:resource => "a", :class => "b")
    metadata = { :table => [table] }
    assert_equal(table, Rets::Metadata::RetsClass.find_table_container(metadata, resource, rets_class))
  end

  def test_rets_class_build
    resource = stub(:resource)
    table_fragment = stub(:fragment)
    table_container = stub(:tables => [table_fragment])
    table = stub(:table)

    Rets::Metadata::TableFactory.expects(:build).with(table_fragment, resource).returns(table)
    Rets::Metadata::RetsClass.expects(:find_table_container).returns(table_container)
    rets_class = Rets::Metadata::RetsClass.build({}, resource, "")
    assert_equal(rets_class.tables, [table])
  end

  def test_rets_class_initialize
    fragment = { "ClassName" => "A" }
    rets_class = Rets::Metadata::RetsClass.new(fragment, "resource")

    assert_equal("A", rets_class.name)
    assert_equal("resource", rets_class.resource)
    assert_equal([], rets_class.tables)
  end

  def test_table_factory_creates_lookup_table
    assert_instance_of Rets::Metadata::LookupTable, Rets::Metadata::TableFactory.build({"LookupName" => "Foo"}, nil)
  end

  def test_table_factory_creates_table
    assert_instance_of Rets::Metadata::Table, Rets::Metadata::TableFactory.build({"LookupName" => ""}, nil)
  end

  def test_table_factory_enum
    assert Rets::Metadata::TableFactory.enum?("LookupName" => "Foo")
    assert !Rets::Metadata::TableFactory.enum?("LookupName" => "")
  end

  def test_lookup_table_initialize
    fragment = { "SystemName" => "A",
                 "Interpretation" => "B",
                 "LookupName" => "C"
               }
    lookup_table = Rets::Metadata::LookupTable.new(fragment, "Foo")
    assert_equal("Foo", lookup_table.resource)
    assert_equal("A", lookup_table.name)
    assert_equal("C", lookup_table.lookup_name)
    assert_equal("B", lookup_table.interpretation)
  end

  def test_lookup_table_resolve_returns_empty_array_when_value_is_empty
    fragment = { "Interpretation" => "SomethingElse" }

    lookup_table = Rets::Metadata::LookupTable.new(fragment, nil)

    assert_equal [], lookup_table.resolve("")
  end

  def test_lookup_table_resolve_returns_single_value_array
    fragment = { "Interpretation" => "SomethingElse" }

    lookup_table = Rets::Metadata::LookupTable.new(fragment, nil)

    lookup_table.expects(:lookup_type).with("A,B").returns(mock(:long_value => "AaaBbb"))

    assert_equal ["AaaBbb"], lookup_table.resolve("A,B")
  end

  def test_lookup_table_resolve_returns_multi_value_array_when_multi
    fragment = { "Interpretation" => "LookupMulti" }

    lookup_table = Rets::Metadata::LookupTable.new(fragment, nil)

    lookup_table.expects(:lookup_type).with("A").returns(mock(:long_value => "Aaa"))
    lookup_table.expects(:lookup_type).with("B").returns(mock(:long_value => "Bbb"))

    assert_equal ["Aaa", "Bbb"], lookup_table.resolve("A,B")
  end

  def test_table_initialize
    fragment = { "DataType" => "A",
                 "SystemName" => "B"
               }

    table = Rets::Metadata::Table.new(fragment)
    assert_equal("A", table.type)
    assert_equal("B", table.name)
  end

  def test_table_resolve_returns_empty_array_when_value_is_empty
    table = Rets::Metadata::Table.new({})

    assert_equal [], table.resolve("")
  end

  def test_table_resolve_returns_single_value_array
    table = Rets::Metadata::Table.new({})

    assert_equal ["Foo"], table.resolve("Foo")
  end

end