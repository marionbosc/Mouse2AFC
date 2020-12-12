// This code has been tested on Arduino Due, it should work on other board types but test please first.
// #define DEBUG
// #define DEBUG_CHAR_INPUT // Rather than sending 2 4-bytes ints on serial, we send 2x (3xChar + 1xunused char), e.g: '999 000\n'
#define START_PIN 3
#define STOP_PIN 4
#define OUTPUT_PIN 8
#define OPTO_FREQ 1000/40.0
#define OPTO_DUTY_CYCLE_PRCNT 80.0

#ifndef DEBUG_CHAR_INPUT
#define FULL_MSG_BYTES_COUNT 8 // Two 4 bytes long
#else
#define FULL_MSG_BYTES_COUNT 1
#define READ_BUF_SIZE 512
char read_buf[READ_BUF_SIZE];
size_t read_count;
#endif
const unsigned int OPTO_DUTY_ON_MILLIS = (OPTO_DUTY_CYCLE_PRCNT/100)*OPTO_FREQ;
const unsigned int OPTO_DUTY_OFF_MILLIS = ((100-OPTO_DUTY_CYCLE_PRCNT)/100)*OPTO_FREQ;
// Have the full duty time as int value to simplify the calculation, that should be almost
// equal to OPTO_FREQ
const unsigned int OPTO_FULL_DUTY_MILLIS = OPTO_DUTY_ON_MILLIS + OPTO_DUTY_OFF_MILLIS;
enum State : byte {NOT_WORKING, COUNTING_OFFSET, WORKING};
long cur_ttl_offset, new_ttl_offset;
long cur_ttl_dur, new_ttl_dur;
unsigned long start_time;
int cur_freq_TTL_state, last_freq_TTL_state;
volatile State should_state;
State cur_state;

void setup() {
  cur_state = should_state = NOT_WORKING;
  Serial.begin(115200);
  pinMode(START_PIN, INPUT_PULLUP);
  pinMode(STOP_PIN, INPUT_PULLUP);
  pinMode(OUTPUT_PIN, OUTPUT);
  pinMode(13, OUTPUT);
  attachInterrupt(digitalPinToInterrupt(START_PIN), triggerStart, RISING);
  attachInterrupt(digitalPinToInterrupt(STOP_PIN), triggerStop, RISING);
}


void loop() {
  int bytes_available = Serial.available();
  if (bytes_available >= FULL_MSG_BYTES_COUNT) {
    #ifndef DEBUG_CHAR_INPUT
    Serial.readBytes((byte*)&new_ttl_offset, 4);
    Serial.readBytes((byte*)&new_ttl_dur, 4);
    #else
    size_t orig_read_idx = read_count;
    read_count += Serial.readBytes((char*)read_buf, READ_BUF_SIZE - read_count);
    bool found_newline = false;
    size_t space_index;
    for (int i = orig_read_idx; i < read_count; i++) {
      if (read_buf[i] == ' ') {
        space_index = i;
        read_buf[i] = '\0'; // So that atio() can handle it
        new_ttl_offset = atoi(&read_buf[orig_read_idx]);
      }
      else if (read_buf[i] == '\n') {
        read_buf[i] = '\0';
        new_ttl_dur = atoi(&read_buf[space_index+1]);
        // Don't use memcpy() to avoid overlapping indices
        for (int j = i+1; j < read_count; j++)
          read_buf[j - i - 1] = read_buf[j];
        read_count = read_count - i;
      }
    }
    #endif
    should_state = NOT_WORKING;
    #ifdef DEBUG
    Serial.print("Received New TTL Offset: ");
    Serial.print(new_ttl_offset);
    Serial.print(" - and duration: ");
    Serial.println(new_ttl_dur);
    #endif
  }

  if (cur_state == NOT_WORKING && (should_state == COUNTING_OFFSET || should_state == WORKING)) {
    start_time = millis();
    cur_state = COUNTING_OFFSET;
    cur_ttl_offset = new_ttl_offset;
    cur_ttl_dur = new_ttl_dur;
    cur_freq_TTL_state = HIGH;
    // Assume last to be low intially, it should only cause 2 subsequent HIGH writes on with cur design
    last_freq_TTL_state = LOW;
    #ifdef DEBUG
    Serial.println("Received start work TTL");
    #endif
  }
  else if (cur_state == COUNTING_OFFSET) {
    if (should_state == NOT_WORKING) {
      digitalWrite(OUTPUT_PIN, LOW);
      digitalWrite(13, LOW);
      cur_state = NOT_WORKING;
      #ifdef DEBUG
      Serial.println("Received stop work TTL");
      #endif
    }
    else if ((unsigned long)(millis() - start_time) >= cur_ttl_offset) {
      digitalWrite(OUTPUT_PIN, HIGH);
      digitalWrite(13, HIGH);
      cur_state = should_state = WORKING;
      #ifdef DEBUG
      Serial.println("Starting TTL output");
      #endif
    }
  }

  if (cur_state == WORKING) {
    long time_active = (unsigned long)(millis() - start_time) - cur_ttl_offset;
    cur_freq_TTL_state = (time_active % OPTO_FULL_DUTY_MILLIS) < OPTO_DUTY_ON_MILLIS  ? HIGH : LOW;
    if (should_state == NOT_WORKING || time_active >= cur_ttl_dur) {
      digitalWrite(OUTPUT_PIN, LOW);
      digitalWrite(13, LOW);
      cur_state = should_state = NOT_WORKING;
      #ifdef DEBUG
      Serial.println("Stopping TTL output");
      #endif
    }
    else if (cur_freq_TTL_state != last_freq_TTL_state) {
      digitalWrite(OUTPUT_PIN, cur_freq_TTL_state);
      digitalWrite(13, cur_freq_TTL_state);
      last_freq_TTL_state = cur_freq_TTL_state;
    }
  }
}

void triggerStart() {
  should_state = COUNTING_OFFSET;
}

void triggerStop() {
  should_state = NOT_WORKING;
}

