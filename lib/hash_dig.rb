# dig a value out of a hash using a dotted notation
#
# { a: { :b => { 'c' => 123 }}}.dig('a.b.c') returns 123
#
# @author David Kelly 2013

class Hash
  def dig dotted_path

    parts = dotted_path.to_s.split('.', 2)
    match = self[parts.first]        unless self[parts.first].nil?
    match = self[parts.first.to_sym] unless self[parts.first.to_sym].nil?

    return nil if match.nil?
    return match.dig(parts[1]) unless parts[1].nil?
    return match
  end
end
