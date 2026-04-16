package com.skyreward.repository;

import com.skyreward.model.Redemption;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

/**
 * Spring Data JPA repository for Redemption entities.
 */
@Repository
public interface RedemptionRepository extends JpaRepository<Redemption, Long> {

    List<Redemption> findByMemberMemberIdOrderByRedemptionDateDesc(Integer memberId);

    List<Redemption> findByMemberMemberIdAndRedemptionDateBetween(
            Integer memberId, LocalDateTime startDate, LocalDateTime endDate);

    Optional<Redemption> findByConfirmationCode(String confirmationCode);

    List<Redemption> findByStatus(String status);
}
