AS   := as
LD   := ld

SRCS := $(wildcard *.s)
OBJS := $(patsubst %.s,build/%.o,$(SRCS))
BIN  := road_shield

.PHONY: all run clean

all: $(BIN)

$(BIN): $(OBJS)
	$(LD) -o $@ $^

build/%.o: %.s
	@mkdir -p build
	$(AS) -o $@ $<

run: $(BIN)
	./$(BIN)

clean:
	rm -rf build $(BIN)
