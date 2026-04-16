-- ============================================================================
-- Reward Fulfillment Queue (pgmq)
-- ============================================================================
-- Migrated from: Oracle Advanced Queuing (DBMS_AQADM)
-- Oracle source:  oracle/queues/reward_fulfillment_queue.sql
--
-- Oracle used a typed payload (reward_fulfillment_msg_t) with AQ queue tables,
-- priority-based sorting, retry policies, and PL/SQL enqueue/dequeue wrappers.
--
-- PostgreSQL uses pgmq (https://github.com/tembo-io/pgmq), which stores
-- messages as JSONB in a lightweight queue table. Key differences:
--   - No typed payloads; messages are JSONB documents.
--   - No built-in priority sorting; priority is stored in the message but
--     consumers process messages in FIFO order.
--   - Retry / expiration must be handled in application logic (pgmq supports
--     visibility timeout for at-least-once delivery).
--   - Oracle AQ's max_retries (5) and retry_delay (300s) have no direct
--     pgmq equivalent; failed messages stay in the queue and become visible
--     again after the visibility timeout expires.
--
-- Prerequisites:
--   CREATE EXTENSION IF NOT EXISTS pgmq;
-- ============================================================================

-- Create the reward_fulfillment queue
SELECT pgmq.create('reward_fulfillment');

-- ============================================================================
-- enqueue_fulfillment
-- ============================================================================
-- Gathers redemption, reward, and member data, then enqueues a JSONB message.
-- Mirrors the Oracle enqueue_fulfillment procedure.
-- ============================================================================
CREATE OR REPLACE FUNCTION enqueue_fulfillment(
    p_redemption_id  BIGINT,
    p_priority       INT DEFAULT 3
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_message  JSONB;
    v_msg_id   BIGINT;
BEGIN
    -- Build the message payload from redemptions, rewards, and members
    SELECT jsonb_build_object(
        'redemption_id',    r.redemption_id,
        'member_id',        r.member_id,
        'reward_id',        r.reward_id,
        'reward_code',      rw.reward_code,
        'reward_name',      rw.reward_name,
        'quantity',          r.quantity,
        'confirmation_code', r.confirmation_code,
        'member_email',     m.email,
        'member_name',      m.first_name || ' ' || m.last_name,
        'fulfillment_type', rw.category,
        'priority',         p_priority,
        'enqueue_time',     CURRENT_TIMESTAMP
    )
    INTO STRICT v_message
    FROM redemptions r
    JOIN rewards rw ON rw.reward_id = r.reward_id
    JOIN members m  ON m.member_id  = r.member_id
    WHERE r.redemption_id = p_redemption_id;

    -- Enqueue to pgmq
    SELECT pgmq.send('reward_fulfillment', v_message)
    INTO v_msg_id;

    RETURN v_msg_id;
END;
$$;

COMMENT ON FUNCTION enqueue_fulfillment(BIGINT, INT)
    IS 'Enqueue a reward-fulfillment message (migrated from Oracle AQ enqueue_fulfillment)';

-- ============================================================================
-- dequeue_and_fulfill
-- ============================================================================
-- Loops reading messages one at a time (30s visibility timeout).
-- For each message:
--   1. Updates the redemption status to FULFILLED.
--   2. Sends a notification to the member.
--   3. Acknowledges (deletes) the message from the queue.
-- Returns the total number of messages processed.
-- ============================================================================
CREATE OR REPLACE FUNCTION dequeue_and_fulfill()
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
    v_rec           RECORD;
    v_msg_id        BIGINT;
    v_message       JSONB;
    v_redemption_id BIGINT;
    v_member_id     BIGINT;
    v_reward_name   TEXT;
    v_confirm_code  TEXT;
    v_member_name   TEXT;
    v_member_email  TEXT;
    v_count         INT := 0;
BEGIN
    LOOP
        -- Read one message with a 30-second visibility timeout
        SELECT *
        INTO v_rec
        FROM pgmq.read('reward_fulfillment', 30, 1)
        LIMIT 1;

        -- Exit when no more messages are available
        IF v_rec IS NULL OR v_rec.msg_id IS NULL THEN
            EXIT;
        END IF;

        v_msg_id   := v_rec.msg_id;
        v_message  := v_rec.message;

        -- Extract fields from the JSONB payload
        v_redemption_id := (v_message ->> 'redemption_id')::BIGINT;
        v_member_id     := (v_message ->> 'member_id')::BIGINT;
        v_reward_name   := v_message ->> 'reward_name';
        v_confirm_code  := v_message ->> 'confirmation_code';
        v_member_name   := v_message ->> 'member_name';
        v_member_email  := v_message ->> 'member_email';

        -- Mark the redemption as fulfilled
        UPDATE redemptions
        SET status           = 'FULFILLED',
            fulfillment_date = CURRENT_TIMESTAMP,
            updated_date     = CURRENT_TIMESTAMP,
            updated_by       = 'QUEUE_PROCESSOR'
        WHERE redemption_id = v_redemption_id;

        -- Send a fulfilment notification to the member
        PERFORM notification_send_notification(
            p_member_id      := v_member_id,
            p_type           := 'REWARD_FULFILLMENT',
            p_subject         := 'Reward Fulfilled: ' || v_reward_name,
            p_body           := 'Dear ' || v_member_name || ', your reward "' ||
                                 v_reward_name || '" (confirmation ' || v_confirm_code ||
                                 ') has been fulfilled.',
            p_channel         := 'EMAIL',
            p_priority        := 2,
            p_scheduled_date  := NULL
        );

        -- Acknowledge the message (remove from queue)
        PERFORM pgmq.delete('reward_fulfillment', v_msg_id);

        v_count := v_count + 1;
    END LOOP;

    RETURN v_count;
END;
$$;

COMMENT ON FUNCTION dequeue_and_fulfill()
    IS 'Dequeue and process reward-fulfillment messages (migrated from Oracle AQ dequeue_and_fulfill)';
