# Makes our doctests a bit cleaner
Code.put_compiler_option(:ignore_module_conflict, true)
# Avoid "Application has been stopped" messages
Logger.put_module_level(:application_controller, :error)
# Do not run remote test by default
ExUnit.configure(exclude: [:remote])
ExUnit.start()
