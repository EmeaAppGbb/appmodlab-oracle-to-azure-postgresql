package com.skyreward.repository;

import com.skyreward.model.Flight;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;

/**
 * Spring Data JPA repository for Flight entities.
 */
@Repository
public interface FlightRepository extends JpaRepository<Flight, Long> {

    List<Flight> findByMemberMemberIdOrderByFlightDateDesc(Integer memberId);

    List<Flight> findByAccrualStatus(String accrualStatus);

    List<Flight> findByMemberMemberIdAndFlightDateBetween(
            Integer memberId, LocalDateTime startDate, LocalDateTime endDate);
}
