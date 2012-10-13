module RethinkDB
  # A write operation, like an insert.
  class Write_Query < RQL_Query
    def apply_variant(variant) # :nodoc:
      return self if variant.nil?
      if variant == :non_atomic
        @body[0] = case @body[0]
                   when :update      then :update_nonatomic
                   when :mutate      then :mutate_nonatomic
                   when :pointupdate then :pointupdate_nonatomic
                   when :pointmutate then :pointmutate_nonatomic
                   else raise RuntimeError,"#{@body[0]} cannot be made nonatomic"
                   end
      else
        raise RuntimeError,"Unknown variant #{@body[0]}; did you mean `:non_atomic`?"
      end
      return self
    end
  end
end
