SRC_DIR=src
TEST=helloworld
TEST_SRCS=$(addprefix $(SRC_DIR)/,init.S $(TEST).c)

mkdir:
	mkdir -p $(TEST)
	cp -f $(TEST_SRCS) $(TEST)
	-cp -f test_script/$(TEST) $(TEST)/test_script
	cp -f subdir.mk $(TEST)/Makefile

compile: mkdir
	$(MAKE) -C $(TEST) TEST=$(TEST) compile

sim: compile
	$(MAKE) -C $(TEST) TEST=$(TEST) sim

gui: compile
	$(MAKE) -C $(TEST) TEST=$(TEST) gui

test: compile
	$(MAKE) -C $(TEST) TEST=$(TEST) test

clean:
	rm -rf $(TEST)
