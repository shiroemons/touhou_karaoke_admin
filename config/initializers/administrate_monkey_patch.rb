Administrate::Order.class_eval do
  def order_by_count(relation)
    relation
      .left_joins(attribute.to_sym)
      .group(relation.primary_key.to_sym)
      .reorder("COUNT(#{attribute}.#{reflect_association(relation).association_primary_key}) #{direction}")
  end
end
