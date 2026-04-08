-- ========================================
-- Oracle Advanced Queuing: Reward Fulfillment Queue
-- ========================================
-- Sets up Oracle AQ for asynchronous reward fulfillment processing

-- Create the queue payload type
CREATE OR REPLACE TYPE reward_fulfillment_msg_t AS OBJECT (
  redemption_id     NUMBER(12),
  member_id         NUMBER(10),
  reward_id         NUMBER(10),
  reward_code       VARCHAR2(30),
  reward_name       VARCHAR2(200),
  quantity          NUMBER(5),
  confirmation_code VARCHAR2(20),
  member_email      VARCHAR2(255),
  member_name       VARCHAR2(200),
  fulfillment_type  VARCHAR2(30),
  priority          NUMBER(1),
  enqueue_time      DATE
);
/

-- Create the queue table
BEGIN
  DBMS_AQADM.CREATE_QUEUE_TABLE(
    queue_table        => 'reward_fulfillment_qt',
    queue_payload_type => 'reward_fulfillment_msg_t',
    sort_list          => 'PRIORITY,ENQ_TIME',
    comment            => 'Queue table for reward fulfillment processing',
    multiple_consumers => FALSE,
    compatible         => '10.0'
  );
END;
/

-- Create the queue
BEGIN
  DBMS_AQADM.CREATE_QUEUE(
    queue_name  => 'reward_fulfillment_q',
    queue_table => 'reward_fulfillment_qt',
    max_retries => 5,
    retry_delay => 300,  -- 5 minute retry delay
    comment     => 'Queue for asynchronous reward fulfillment requests'
  );
END;
/

-- Start the queue
BEGIN
  DBMS_AQADM.START_QUEUE(queue_name => 'reward_fulfillment_q');
END;
/

-- ----------------------------------------
-- Enqueue procedure
-- ----------------------------------------
CREATE OR REPLACE PROCEDURE enqueue_fulfillment(
  p_redemption_id   IN NUMBER,
  p_priority        IN NUMBER DEFAULT 3
) IS
  v_enqueue_options    DBMS_AQ.ENQUEUE_OPTIONS_T;
  v_message_properties DBMS_AQ.MESSAGE_PROPERTIES_T;
  v_message_handle     RAW(16);
  v_message            reward_fulfillment_msg_t;

  v_member_id    NUMBER;
  v_reward_id    NUMBER;
  v_reward_code  VARCHAR2(30);
  v_reward_name  VARCHAR2(200);
  v_quantity     NUMBER;
  v_confirm_code VARCHAR2(20);
  v_email        VARCHAR2(255);
  v_name         VARCHAR2(200);
  v_category     VARCHAR2(50);
BEGIN
  -- Gather fulfillment details
  SELECT r.member_id, r.reward_id, rw.reward_code, rw.reward_name,
         r.quantity, r.confirmation_code, m.email,
         m.first_name || ' ' || m.last_name, rw.category
  INTO v_member_id, v_reward_id, v_reward_code, v_reward_name,
       v_quantity, v_confirm_code, v_email, v_name, v_category
  FROM redemptions r
  JOIN rewards rw ON r.reward_id = rw.reward_id
  JOIN members m ON r.member_id = m.member_id
  WHERE r.redemption_id = p_redemption_id;

  -- Build message
  v_message := reward_fulfillment_msg_t(
    redemption_id     => p_redemption_id,
    member_id         => v_member_id,
    reward_id         => v_reward_id,
    reward_code       => v_reward_code,
    reward_name       => v_reward_name,
    quantity          => v_quantity,
    confirmation_code => v_confirm_code,
    member_email      => v_email,
    member_name       => v_name,
    fulfillment_type  => v_category,
    priority          => p_priority,
    enqueue_time      => SYSDATE
  );

  v_message_properties.priority := p_priority;
  v_message_properties.expiration := 86400; -- 24 hour expiration

  DBMS_AQ.ENQUEUE(
    queue_name         => 'reward_fulfillment_q',
    enqueue_options    => v_enqueue_options,
    message_properties => v_message_properties,
    payload            => v_message,
    msgid              => v_message_handle
  );

  COMMIT;
END enqueue_fulfillment;
/

-- ----------------------------------------
-- Dequeue and process procedure
-- ----------------------------------------
CREATE OR REPLACE PROCEDURE dequeue_and_fulfill IS
  v_dequeue_options    DBMS_AQ.DEQUEUE_OPTIONS_T;
  v_message_properties DBMS_AQ.MESSAGE_PROPERTIES_T;
  v_message_handle     RAW(16);
  v_message            reward_fulfillment_msg_t;
  v_no_messages        BOOLEAN := FALSE;
BEGIN
  v_dequeue_options.wait := DBMS_AQ.NO_WAIT;
  v_dequeue_options.navigation := DBMS_AQ.FIRST_MESSAGE;

  LOOP
    BEGIN
      DBMS_AQ.DEQUEUE(
        queue_name         => 'reward_fulfillment_q',
        dequeue_options    => v_dequeue_options,
        message_properties => v_message_properties,
        payload            => v_message,
        msgid              => v_message_handle
      );

      -- Process fulfillment based on type
      DBMS_OUTPUT.PUT_LINE('Processing fulfillment for redemption ' || v_message.redemption_id ||
                           ' - ' || v_message.reward_name || ' for ' || v_message.member_name);

      -- Mark redemption as fulfilled
      UPDATE redemptions SET
        status           = 'FULFILLED',
        fulfillment_date = SYSDATE,
        updated_date     = SYSDATE
      WHERE redemption_id = v_message.redemption_id;

      -- Send fulfillment notification
      pkg_notification.send_notification(
        v_message.member_id, 'REDEMPTION_CONFIRM',
        'Your Reward Has Been Fulfilled - ' || v_message.reward_name,
        'Dear ' || v_message.member_name || ',' || CHR(10) ||
        'Your reward ' || v_message.reward_name || ' (Confirmation: ' ||
        v_message.confirmation_code || ') has been fulfilled.' || CHR(10) ||
        'Thank you for being a SkyReward member!'
      );

      COMMIT;

      v_dequeue_options.navigation := DBMS_AQ.NEXT_MESSAGE;

    EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE = -25228 THEN -- No messages
          v_no_messages := TRUE;
        ELSE
          DBMS_OUTPUT.PUT_LINE('Error processing message: ' || SQLERRM);
          ROLLBACK;
        END IF;
        EXIT WHEN v_no_messages;
    END;
  END LOOP;
END dequeue_and_fulfill;
/
