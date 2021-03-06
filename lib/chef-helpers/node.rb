require 'chef/node'
require 'jsonpath'

class Chef::Node

  # Node's "allies" are all nodes in the same environment (if the
  # environment is not `_default`), and nodes specified by `allies`
  # attribute. The `allies` attribute - if set - should be an array of
  # node names or node search queries; the named nodes and search
  # results will be added to node's allies.
  #
  # This is mostly useful when defining firewall or other access
  # rules, to easily limit access to insides of a cluster plus a
  # handful of friendly machines.
  #
  # @return [Array<Chef::Node>] Array of node's "allies".
  def allies
    @allies ||=
      begin
        rv = []
        q =  Chef::Search::Query.new
        rv += q.search(:node, "chef_environment:#{self.chef_environment}").first unless self.chef_environment == '_default'
        if self['allies']
          self['allies'].each do |ally|
            ally = "name:#{ally}" unless ally.include?(':')
            rv += q.search(:node, ally).first
          end
        end
        rv
      end
  end

  # Find out, which IP should be used to contact with other node.
  #
  # If both nodes are on EC2 and in the same region, then other node's
  # `ec2.local_ipv4` attribute is used. Otherwise, if other node is a
  # cloud instance, its `cloud_public.ipv4` attribute is
  # used. Otherwise, other node's `ipaddress` is used.
  #
  # @note This method may return wrong IP with non-EC2 cloud
  #       providers, and can use some tweaking for such cases.
  # @param [Chef::Node] other_node Node, whose IP we need to know
  # @return [String] IP of `other_node`
  def ip_for(other_node)
    # Strip last letter from availability zone to get region.
    if other_node['ec2'] && self['ec2'] &&
       self['ec2']['placement_availability_zone'].sub(/[a-z]$/,'') == other_node['ec2']['placement_availability_zone'].sub(/[a-z]$/,'')
      other_node['ec2']['local_ipv4']
    elsif other_node['cloud']
      other_node['cloud']['public_ipv4']
    else
      other_node['ipaddress']
    end
  end

  # jsonpath access to node attributes
  def brackets_with_jsonpath(key)
    case key
    when JsonPath then key.on(self.to_hash)
    when /^\$/    then JsonPath.on(self.to_hash, key)
    else               self.brackets_without_jsonpath(key)
    end
  end
  alias_method :brackets_without_jsonpath, :[]
  alias_method :[], :brackets_with_jsonpath
end
