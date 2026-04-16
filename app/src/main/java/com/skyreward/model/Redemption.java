package com.skyreward.model;

import jakarta.persistence.*;
import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * JPA entity for the redemptions table.
 *
 * Migration notes (Oracle → PostgreSQL):
 * - Oracle NUMBER(12) for redemption_id mapped to Long (BIGINT).
 * - Oracle DATE columns mapped to LocalDateTime (PostgreSQL TIMESTAMP).
 * - Foreign keys to members and rewards preserved; lazy-fetched to avoid N+1.
 */
@Entity
@Table(name = "redemptions")
public class Redemption {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "redemption_id")
    private Long redemptionId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "member_id", nullable = false)
    private Member member;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "reward_id", nullable = false)
    private Reward reward;

    @Column(name = "redemption_date")
    private LocalDateTime redemptionDate;

    @NotNull
    @Column(name = "miles_used", nullable = false)
    private Integer milesUsed;

    @Column(name = "cash_paid", precision = 10, scale = 2)
    private BigDecimal cashPaid = BigDecimal.ZERO;

    @Column(name = "quantity")
    private Integer quantity = 1;

    @Column(name = "confirmation_code", length = 20)
    private String confirmationCode;

    @Column(name = "fulfillment_date")
    private LocalDateTime fulfillmentDate;

    @Column(name = "expiry_date")
    private LocalDateTime expiryDate;

    @Column(name = "redemption_channel", length = 30)
    private String redemptionChannel = "WEB";

    @Column(name = "status", length = 20)
    private String status = "PENDING";

    @Column(name = "notes", columnDefinition = "TEXT")
    private String notes;

    @Column(name = "created_date")
    private LocalDateTime createdDate;

    @Column(name = "updated_date")
    private LocalDateTime updatedDate;

    public Redemption() {
    }

    // Getters and setters

    public Long getRedemptionId() {
        return redemptionId;
    }

    public void setRedemptionId(Long redemptionId) {
        this.redemptionId = redemptionId;
    }

    public Member getMember() {
        return member;
    }

    public void setMember(Member member) {
        this.member = member;
    }

    public Reward getReward() {
        return reward;
    }

    public void setReward(Reward reward) {
        this.reward = reward;
    }

    public LocalDateTime getRedemptionDate() {
        return redemptionDate;
    }

    public void setRedemptionDate(LocalDateTime redemptionDate) {
        this.redemptionDate = redemptionDate;
    }

    public Integer getMilesUsed() {
        return milesUsed;
    }

    public void setMilesUsed(Integer milesUsed) {
        this.milesUsed = milesUsed;
    }

    public BigDecimal getCashPaid() {
        return cashPaid;
    }

    public void setCashPaid(BigDecimal cashPaid) {
        this.cashPaid = cashPaid;
    }

    public Integer getQuantity() {
        return quantity;
    }

    public void setQuantity(Integer quantity) {
        this.quantity = quantity;
    }

    public String getConfirmationCode() {
        return confirmationCode;
    }

    public void setConfirmationCode(String confirmationCode) {
        this.confirmationCode = confirmationCode;
    }

    public LocalDateTime getFulfillmentDate() {
        return fulfillmentDate;
    }

    public void setFulfillmentDate(LocalDateTime fulfillmentDate) {
        this.fulfillmentDate = fulfillmentDate;
    }

    public LocalDateTime getExpiryDate() {
        return expiryDate;
    }

    public void setExpiryDate(LocalDateTime expiryDate) {
        this.expiryDate = expiryDate;
    }

    public String getRedemptionChannel() {
        return redemptionChannel;
    }

    public void setRedemptionChannel(String redemptionChannel) {
        this.redemptionChannel = redemptionChannel;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public String getNotes() {
        return notes;
    }

    public void setNotes(String notes) {
        this.notes = notes;
    }

    public LocalDateTime getCreatedDate() {
        return createdDate;
    }

    public void setCreatedDate(LocalDateTime createdDate) {
        this.createdDate = createdDate;
    }

    public LocalDateTime getUpdatedDate() {
        return updatedDate;
    }

    public void setUpdatedDate(LocalDateTime updatedDate) {
        this.updatedDate = updatedDate;
    }
}
