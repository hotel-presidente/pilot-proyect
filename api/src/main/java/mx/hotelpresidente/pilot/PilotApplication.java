package mx.hotelpresidente.pilot;

import java.util.Map;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@SpringBootApplication
@RestController
public class PilotApplication {

	public static void main(String[] args) {
		SpringApplication.run(PilotApplication.class, args);
	}

	@GetMapping("/")
	Map<String, String> root() {
		return Map.of("service", "hotel-presidente-api", "status", "boilerplate");
	}
}
