package com.skyreward.model;

import jakarta.persistence.*;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * JPA entity for the members table.
 *
 * Migration notes (Oracle → PostgreSQL):
 * - GenerationType.SEQUENCE with explicit generator replaces Oracle sequence-based triggers.
 *   The PostgreSQL schema uses sequences wired via ALTER TABLE ... SET DEFAULT nextval(...).
 * - Oracle NUMBER mapped to Integer/Long; VARCHAR2 mapped to String (VARCHAR).
 * - Oracle DATE (which includes time) mapped to LocalDateTime (TIMESTAMP in PostgreSQL).
 * - Oracle CLOB mapped to TEXT via @Column(columnDefinition = "TEXT").
 */
@Entity
@Table(name = "members")
public class Member {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "member_id")
    private Integer memberId;

    @Column(name = "membership_number", nullable = false, unique = true, length = 20)
    private String membershipNumber;

    @NotBlank
    @Size(max = 100)
    @Column(name = "first_name", nullable = false, length = 100)
    private String firstName;

    @NotBlank
    @Size(max = 100)
    @Column(name = "last_name", nullable = false, length = 100)
    private String lastName;

    @Email
    @NotBlank
    @Column(name = "email", nullable = false, unique = true, length = 255)
    private String email;

    @Column(name = "phone", length = 30)
    private String phone;

    @Column(name = "date_of_birth")
    private LocalDate dateOfBirth;

    @Column(name = "gender", length = 1)
    private String gender;

    @Column(name = "address_line1", length = 255)
    private String addressLine1;

    @Column(name = "address_line2", length = 255)
    private String addressLine2;

    @Column(name = "city", length = 100)
    private String city;

    @Column(name = "state_province", length = 100)
    private String stateProvince;

    @Column(name = "postal_code", length = 20)
    private String postalCode;

    @Column(name = "country", length = 3)
    private String country = "US";

    @Column(name = "tier_status", length = 20)
    private String tierStatus = "BLUE";

    @Column(name = "total_miles")
    private Long totalMiles = 0L;

    @Column(name = "available_miles")
    private Long availableMiles = 0L;

    @Column(name = "ytd_miles")
    private Long ytdMiles = 0L;

    @Column(name = "lifetime_miles")
    private Long lifetimeMiles = 0L;

    @Column(name = "enrollment_date")
    private LocalDateTime enrollmentDate;

    @Column(name = "tier_expiry_date")
    private LocalDateTime tierExpiryDate;

    @Column(name = "last_activity_date")
    private LocalDateTime lastActivityDate;

    @Column(name = "preferred_airport", length = 5)
    private String preferredAirport;

    @Column(name = "preferred_language", length = 5)
    private String preferredLanguage = "en";

    @Column(name = "communication_pref", length = 20)
    private String communicationPref = "EMAIL";

    @Column(name = "status", length = 20)
    private String status = "ACTIVE";

    @Column(name = "notes", columnDefinition = "TEXT")
    private String notes;

    @Column(name = "created_date")
    private LocalDateTime createdDate;

    @Column(name = "updated_date")
    private LocalDateTime updatedDate;

    @Column(name = "created_by", length = 50)
    private String createdBy;

    @Column(name = "updated_by", length = 50)
    private String updatedBy;

    public Member() {
    }

    // Getters and setters

    public Integer getMemberId() {
        return memberId;
    }

    public void setMemberId(Integer memberId) {
        this.memberId = memberId;
    }

    public String getMembershipNumber() {
        return membershipNumber;
    }

    public void setMembershipNumber(String membershipNumber) {
        this.membershipNumber = membershipNumber;
    }

    public String getFirstName() {
        return firstName;
    }

    public void setFirstName(String firstName) {
        this.firstName = firstName;
    }

    public String getLastName() {
        return lastName;
    }

    public void setLastName(String lastName) {
        this.lastName = lastName;
    }

    public String getEmail() {
        return email;
    }

    public void setEmail(String email) {
        this.email = email;
    }

    public String getPhone() {
        return phone;
    }

    public void setPhone(String phone) {
        this.phone = phone;
    }

    public LocalDate getDateOfBirth() {
        return dateOfBirth;
    }

    public void setDateOfBirth(LocalDate dateOfBirth) {
        this.dateOfBirth = dateOfBirth;
    }

    public String getGender() {
        return gender;
    }

    public void setGender(String gender) {
        this.gender = gender;
    }

    public String getAddressLine1() {
        return addressLine1;
    }

    public void setAddressLine1(String addressLine1) {
        this.addressLine1 = addressLine1;
    }

    public String getAddressLine2() {
        return addressLine2;
    }

    public void setAddressLine2(String addressLine2) {
        this.addressLine2 = addressLine2;
    }

    public String getCity() {
        return city;
    }

    public void setCity(String city) {
        this.city = city;
    }

    public String getStateProvince() {
        return stateProvince;
    }

    public void setStateProvince(String stateProvince) {
        this.stateProvince = stateProvince;
    }

    public String getPostalCode() {
        return postalCode;
    }

    public void setPostalCode(String postalCode) {
        this.postalCode = postalCode;
    }

    public String getCountry() {
        return country;
    }

    public void setCountry(String country) {
        this.country = country;
    }

    public String getTierStatus() {
        return tierStatus;
    }

    public void setTierStatus(String tierStatus) {
        this.tierStatus = tierStatus;
    }

    public Long getTotalMiles() {
        return totalMiles;
    }

    public void setTotalMiles(Long totalMiles) {
        this.totalMiles = totalMiles;
    }

    public Long getAvailableMiles() {
        return availableMiles;
    }

    public void setAvailableMiles(Long availableMiles) {
        this.availableMiles = availableMiles;
    }

    public Long getYtdMiles() {
        return ytdMiles;
    }

    public void setYtdMiles(Long ytdMiles) {
        this.ytdMiles = ytdMiles;
    }

    public Long getLifetimeMiles() {
        return lifetimeMiles;
    }

    public void setLifetimeMiles(Long lifetimeMiles) {
        this.lifetimeMiles = lifetimeMiles;
    }

    public LocalDateTime getEnrollmentDate() {
        return enrollmentDate;
    }

    public void setEnrollmentDate(LocalDateTime enrollmentDate) {
        this.enrollmentDate = enrollmentDate;
    }

    public LocalDateTime getTierExpiryDate() {
        return tierExpiryDate;
    }

    public void setTierExpiryDate(LocalDateTime tierExpiryDate) {
        this.tierExpiryDate = tierExpiryDate;
    }

    public LocalDateTime getLastActivityDate() {
        return lastActivityDate;
    }

    public void setLastActivityDate(LocalDateTime lastActivityDate) {
        this.lastActivityDate = lastActivityDate;
    }

    public String getPreferredAirport() {
        return preferredAirport;
    }

    public void setPreferredAirport(String preferredAirport) {
        this.preferredAirport = preferredAirport;
    }

    public String getPreferredLanguage() {
        return preferredLanguage;
    }

    public void setPreferredLanguage(String preferredLanguage) {
        this.preferredLanguage = preferredLanguage;
    }

    public String getCommunicationPref() {
        return communicationPref;
    }

    public void setCommunicationPref(String communicationPref) {
        this.communicationPref = communicationPref;
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

    public String getCreatedBy() {
        return createdBy;
    }

    public void setCreatedBy(String createdBy) {
        this.createdBy = createdBy;
    }

    public String getUpdatedBy() {
        return updatedBy;
    }

    public void setUpdatedBy(String updatedBy) {
        this.updatedBy = updatedBy;
    }
}
