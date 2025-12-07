package com.onkyarity.testapi.controller;

import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@CrossOrigin(origins = "*")
public class ApiController {

  @GetMapping("/")
  public String index() {
    return "Hello Onkyarity Updated Again Successfully !!";
  }

}
