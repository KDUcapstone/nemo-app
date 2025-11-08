// backend/src/main/java/com/nemo/backend/domain/user/repository/UserRepository.java
package com.nemo.backend.domain.user.repository;

import com.nemo.backend.domain.user.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface UserRepository extends JpaRepository<User, Long> {
    Optional<User> findByEmail(String email);
    boolean existsByEmail(String email);
}
