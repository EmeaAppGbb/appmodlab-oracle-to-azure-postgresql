package com.skyreward.model;

import jakarta.persistence.*;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * JPA entity for the flights table.
 *
 * Migration notes (Oracle → PostgreSQL):
 * - Oracle NUMBER(12) mapped to Long (BIGINT in PostgreSQL).
 * - Oracle DATE columns mapped to LocalDateTime (TIMESTAMP in PostgreSQL)
 *   because Oracle DATE includes time component.
 * - CHECK constraints on cabin_class, accrual_status, status remain enforced
 *   at the database level; the application trusts the DB constraints.
 */
@Entity
@Table(name = "flights")
public class Flight {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "flight_id")
    private Long flightId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "member_id", nullable = false)
    private Member member;

    @NotBlank
    @Column(name = "flight_number", nullable = false, length = 10)
    private String flightNumber;

    @NotBlank
    @Column(name = "airline_code", nullable = false, length = 3)
    private String airlineCode;

    @NotBlank
    @Column(name = "departure_airport", nullable = false, length = 5)
    private String departureAirport;

    @NotBlank
    @Column(name = "arrival_airport", nullable = false, length = 5)
    private String arrivalAirport;

    @NotNull
    @Column(name = "flight_date", nullable = false)
    private LocalDateTime flightDate;

    @NotBlank
    @Column(name = "booking_class", nullable = false, length = 2)
    private String bookingClass;

    @NotBlank
    @Column(name = "cabin_class", nullable = false, length = 20)
    private String cabinClass;

    @Column(name = "ticket_number", length = 20)
    private String ticketNumber;

    @Column(name = "pnr_locator", length = 10)
    private String pnrLocator;

    @Column(name = "distance_miles", nullable = false)
    private Integer distanceMiles;

    @Column(name = "base_miles", nullable = false)
    private Integer baseMiles;

    @Column(name = "bonus_miles")
    private Integer bonusMiles = 0;

    @Column(name = "tier_miles")
    private Integer tierMiles = 0;

    @Column(name = "total_miles", nullable = false)
    private Integer totalMiles;

    @Column(name = "fare_amount", precision = 10, scale = 2)
    private BigDecimal fareAmount;

    @Column(name = "fare_currency", length = 3)
    private String fareCurrency = "USD";

    @Column(name = "accrual_status", length = 20)
    private String accrualStatus = "PENDING";

    @Column(name = "processed_date")
    private LocalDateTime processedDate;

    @Column(name = "partner_code", length = 10)
    private String partnerCode;

    @Column(name = "status", length = 20)
    private String status = "ACTIVE";

    @Column(name = "created_date")
    private LocalDateTime createdDate;

    @Column(name = "updated_date")
    private LocalDateTime updatedDate;

    public Flight() {
    }

    // Getters and setters

    public Long getFlightId() {
        return flightId;
    }

    public void setFlightId(Long flightId) {
        this.flightId = flightId;
    }

    public Member getMember() {
        return member;
    }

    public void setMember(Member member) {
        this.member = member;
    }

    public String getFlightNumber() {
        return flightNumber;
    }

    public void setFlightNumber(String flightNumber) {
        this.flightNumber = flightNumber;
    }

    public String getAirlineCode() {
        return airlineCode;
    }

    public void setAirlineCode(String airlineCode) {
        this.airlineCode = airlineCode;
    }

    public String getDepartureAirport() {
        return departureAirport;
    }

    public void setDepartureAirport(String departureAirport) {
        this.departureAirport = departureAirport;
    }

    public String getArrivalAirport() {
        return arrivalAirport;
    }

    public void setArrivalAirport(String arrivalAirport) {
        this.arrivalAirport = arrivalAirport;
    }

    public LocalDateTime getFlightDate() {
        return flightDate;
    }

    public void setFlightDate(LocalDateTime flightDate) {
        this.flightDate = flightDate;
    }

    public String getBookingClass() {
        return bookingClass;
    }

    public void setBookingClass(String bookingClass) {
        this.bookingClass = bookingClass;
    }

    public String getCabinClass() {
        return cabinClass;
    }

    public void setCabinClass(String cabinClass) {
        this.cabinClass = cabinClass;
    }

    public String getTicketNumber() {
        return ticketNumber;
    }

    public void setTicketNumber(String ticketNumber) {
        this.ticketNumber = ticketNumber;
    }

    public String getPnrLocator() {
        return pnrLocator;
    }

    public void setPnrLocator(String pnrLocator) {
        this.pnrLocator = pnrLocator;
    }

    public Integer getDistanceMiles() {
        return distanceMiles;
    }

    public void setDistanceMiles(Integer distanceMiles) {
        this.distanceMiles = distanceMiles;
    }

    public Integer getBaseMiles() {
        return baseMiles;
    }

    public void setBaseMiles(Integer baseMiles) {
        this.baseMiles = baseMiles;
    }

    public Integer getBonusMiles() {
        return bonusMiles;
    }

    public void setBonusMiles(Integer bonusMiles) {
        this.bonusMiles = bonusMiles;
    }

    public Integer getTierMiles() {
        return tierMiles;
    }

    public void setTierMiles(Integer tierMiles) {
        this.tierMiles = tierMiles;
    }

    public Integer getTotalMiles() {
        return totalMiles;
    }

    public void setTotalMiles(Integer totalMiles) {
        this.totalMiles = totalMiles;
    }

    public BigDecimal getFareAmount() {
        return fareAmount;
    }

    public void setFareAmount(BigDecimal fareAmount) {
        this.fareAmount = fareAmount;
    }

    public String getFareCurrency() {
        return fareCurrency;
    }

    public void setFareCurrency(String fareCurrency) {
        this.fareCurrency = fareCurrency;
    }

    public String getAccrualStatus() {
        return accrualStatus;
    }

    public void setAccrualStatus(String accrualStatus) {
        this.accrualStatus = accrualStatus;
    }

    public LocalDateTime getProcessedDate() {
        return processedDate;
    }

    public void setProcessedDate(LocalDateTime processedDate) {
        this.processedDate = processedDate;
    }

    public String getPartnerCode() {
        return partnerCode;
    }

    public void setPartnerCode(String partnerCode) {
        this.partnerCode = partnerCode;
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
