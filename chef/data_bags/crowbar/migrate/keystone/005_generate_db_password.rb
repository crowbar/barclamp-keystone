def upgrade ta, td, a, d
  if a['db']['password'].nil? || a['db']['password'].empty?
    # old proposals had passwords created in the cookbook
    service = ServiceObject.new "fake-logger"
    a['db']['password'] = service.random_password
  end
  return a, d
end

def downgrade ta, td, a, d
  return a, d
end
