# grobid_server_info returns default values when no server is configured

    Code
      res <- grobid_server_info()
    Message
      
      -- GROBID Server ---------------------------------------------------------------
      Mode: not configured
      URL: -
      Reachable: no
      Version: unknown
      Timeout: -

# grobid_server_info returns correct info when server is configured and reachable

    Code
      res <- grobid_server_info()
    Message
      
      -- GROBID Server ---------------------------------------------------------------
      Mode: docker
      URL: http://localhost:8070
      Reachable: yes
      Version: 0.9.0
      Timeout: 120s

# grobid_server_info returns api_reachable = FALSE when server is configured but unreachable

    Code
      res <- grobid_server_info()
    Message
      
      -- GROBID Server ---------------------------------------------------------------
      Mode: remote
      URL: https://grobidorg-grobid.hf.space
      Reachable: no
      Version: unknown
      Timeout: 10s

