package com.skyreward.model;

import jakarta.persistence.*;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * JPA entity for the rewards table.
 *
 * Migration notes (Oracle → PostgreSQL):
 * - Oracle CLOB (description, terms_conditions) mapped to TEXT.
 * - Oracle NUMBER(10,2) mapped to BigDecimal with NUMERIC(10,2).
 * - Oracle SYSDATE defaults handled by PostgreSQL CURRENT_TIMESTAMP.
 */
@Entity
@Table(name = "rewards")
public class Reward {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "reward_id")
    private Integer rewardId;

    @NotBlank
    @Column(name = "reward_code", nullable = false, unique = true, length = 30)
    private String rewardCode;

    @NotBlank
    @Column(name = "reward_name", nullable = false, length = 200)
    private String rewardName;

    @Column(name = "description", columnDefinition = "TEXT")
    private String description;

    @NotBlank
    @Column(name = "category", nullable = false, length = 50)
    private String category;

    @Column(name = "subcategory", length = 50)
    private String subcategory;

    @NotNull
    @Column(name = "miles_required", nullable = false)
    private Integer milesRequired;

    @Column(name = "cash_copay", precision = 10, scale = 2)
    private BigDecimal cashCopay = BigDecimal.ZERO;

    @Column(name = "quantity_available")
    private Integer quantityAvailable;

    @Column(name = "min_tier_required", length = 20)
    private String minTierRequired = "BLUE";

    @Column(name = "partner_id")
    private Integer partnerId;

    @Column(name = "valid_from")
    private LocalDateTime validFrom;

    @Column(name = "valid_until")
    private LocalDateTime validUntil;

    @Column(name = "terms_conditions", columnDefinition = "TEXT")
    private String termsConditions;

    @Column(name = "image_url", length = 500)
    private String imageUrl;

    @Column(name = "status", length = 20)
    private String status = "ACTIVE";

    @Column(name = "created_date")
    private LocalDateTime createdDate;

    @Column(name = "updated_date")
    private LocalDateTime updatedDate;

    public Reward() {
    }

    // Getters and setters

    public Integer getRewardId() {
        return rewardId;
    }

    public void setRewardId(Integer rewardId) {
        this.rewardId = rewardId;
    }

    public String getRewardCode() {
        return rewardCode;
    }

    public void setRewardCode(String rewardCode) {
        this.rewardCode = rewardCode;
    }

    public String getRewardName() {
        return rewardName;
    }

    public void setRewardName(String rewardName) {
        this.rewardName = rewardName;
    }

    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public String getCategory() {
        return category;
    }

    public void setCategory(String category) {
        this.category = category;
    }

    public String getSubcategory() {
        return subcategory;
    }

    public void setSubcategory(String subcategory) {
        this.subcategory = subcategory;
    }

    public Integer getMilesRequired() {
        return milesRequired;
    }

    public void setMilesRequired(Integer milesRequired) {
        this.milesRequired = milesRequired;
    }

    public BigDecimal getCashCopay() {
        return cashCopay;
    }

    public void setCashCopay(BigDecimal cashCopay) {
        this.cashCopay = cashCopay;
    }

    public Integer getQuantityAvailable() {
        return quantityAvailable;
    }

    public void setQuantityAvailable(Integer quantityAvailable) {
        this.quantityAvailable = quantityAvailable;
    }

    public String getMinTierRequired() {
        return minTierRequired;
    }

    public void setMinTierRequired(String minTierRequired) {
        this.minTierRequired = minTierRequired;
    }

    public Integer getPartnerId() {
        return partnerId;
    }

    public void setPartnerId(Integer partnerId) {
        this.partnerId = partnerId;
    }

    public LocalDateTime getValidFrom() {
        return validFrom;
    }

    public void setValidFrom(LocalDateTime validFrom) {
        this.validFrom = validFrom;
    }

    public LocalDateTime getValidUntil() {
        return validUntil;
    }

    public void setValidUntil(LocalDateTime validUntil) {
        this.validUntil = validUntil;
    }

    public String getTermsConditions() {
        return termsConditions;
    }

    public void setTermsConditions(String termsConditions) {
        this.termsConditions = termsConditions;
    }

    public String getImageUrl() {
        return imageUrl;
    }

    public void setImageUrl(String imageUrl) {
        this.imageUrl = imageUrl;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
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
