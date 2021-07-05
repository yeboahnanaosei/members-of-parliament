import net.http
import net.html
import json

struct Member {
	name         string
	party        string
	party_abbr   string
	constituency string
	region       string
	photo        string
}

const base_url = 'https://www.parliament.gh'

fn get_page_links(base_url string) ?[]string {
	res := http.get(base_url) ?
	document := html.parse(res.text)
	anchor_tags := document.get_tag('a')

	mut page_links := []string{}
	for tag in anchor_tags {
		if 'class' in tag.attributes && tag.attributes['class'].contains('square') {
			page_links << tag.attributes['href']
		}
	}
	return page_links
}

fn get_members(url string) []Member {
	res := http.get(url) or { return []Member{} }
	document := html.parse(res.text)
	mp_divs := document.get_tag('div')
	mut members := []Member{}

	for div in mp_divs {
		// We are looking for divs that have the attribute 'class' set to a value
		if 'class' !in div.attributes {
			continue
		}

		// If the class attribute is set above then we are looking for class
		// that contain the word 'mpcard'
		if !div.attributes['class'].contains('mpcard') {
			continue
		}

		party_details := div.children[0].children[1].children[1].children[1].content.split('(')
		members << Member{
			name: div.children[0].children[1].children[1].children[0].content.split(' ').filter(it.trim_space().len > 0).map(it.to_upper()).join(' ')
			party: party_details[0].trim_space().to_upper()
			party_abbr: party_details[1].trim(' )(').to_upper()
			constituency: div.children[0].children[1].children[1].children[3].content.to_upper()
			region: div.children[0].children[1].children[1].children[5].content.to_upper()
			photo: '$base_url/${div.children[0].children[0].attributes['src']}'
		}
	}
	return members
}

fn main() {
	page_links := get_page_links(base_url+"/mps?az") or {
		println('cannot continue: $err')
		return
	}

	mut threads := []thread []Member{}
	for link in page_links {
		threads << go get_members('$base_url/$link')
	}
	members_arr := threads.wait()

	mut final_data := []Member{len: 275, cap: 275}

	// FIXME: Fix nested for loop
	for members in members_arr {
		for mp in members {
			final_data << mp
		}
	}

	println(json.encode(final_data))
}
