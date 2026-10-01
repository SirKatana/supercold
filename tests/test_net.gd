extends "res://tests/test_case.gd"
## LAN codes: packing an address into six characters and getting it back again.


func after_each() -> void:
	Net.close()


func test_a_code_is_six_readable_characters() -> void:
	var code: String = Net.pack("192.168.1.42", Net.PORT_BASE)
	check_eq(code.length(), 6, "six of them: %s" % code)
	for i: int in code.length():
		check(Net.ALPHABET.contains(code[i]), "%s is a character somebody can read out" % code[i])
	check(not code.contains("I"), "nothing that reads as a one")
	check(not code.contains("O"), "nothing that reads as a zero")


func test_a_code_comes_back_as_the_address_it_went_in_as() -> void:
	for address: String in ["192.168.1.42", "10.0.0.7", "192.168.255.255", "172.16.4.9"]:
		for port: int in [Net.PORT_BASE, Net.PORT_BASE + 5, Net.PORT_BASE + 31]:
			var code: String = Net.pack(address, port)
			var back: Array = Net.unpack(code)
			check(not back.is_empty(), "%s:%d unpacks" % [address, port])
			var bits: PackedStringArray = address.split(".")
			check_eq(back[0], int(bits[2]), "third number of %s" % address)
			check_eq(back[1], int(bits[3]), "fourth number of %s" % address)
			check_eq(back[2], port, "the port of %s" % address)


func test_rubbish_is_not_a_code() -> void:
	for bad: String in ["", "12345", "1234567", "ABC!EF", "IIIIII"]:
		check(Net.unpack(bad).is_empty(), "%s is refused" % bad)


func test_lower_case_and_spaces_are_forgiven() -> void:
	var code: String = Net.pack("192.168.3.11", Net.PORT_BASE + 2)
	check_eq(Net.unpack(code.to_lower()), Net.unpack(code), "typed in lower case")
	check_eq(Net.unpack("  %s  " % code), Net.unpack(code), "typed with spaces round it")


func test_it_starts_switched_off() -> void:
	check_eq(Net.role, Net.Role.OFF, "no game open")
	check(not Net.is_online(), "and nothing connected")
	check(Net.is_host(), "a game on its own is its own host")
