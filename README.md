# highlighter.sh
Tool that runs commands concurrently and takes a screenshot of the output highlighting user specified strings through regular expressions

# Help
## Usage:
./highlighter.sh -c command -h input_target(s) -r regex -t max_threads_to_run -O output_path_or_file
## Examples: 
### Read domains/ips from a file and highlight the server header
```bash
./highlighter.sh -c "curl -I -s _target_" -h targets.txt -r "(server.*)\r" -t 3 -O server-header-
```
### Highlight open ports on a single domain/ip
```bash
./highlighter.sh -c "nmap -F -sT _target_" -h scanme.nmap.org -r "(.*open.*)"
```
